#include "zarchivereader.h"
#include <zstd.h>
#include <cassert>
#include <fstream>
#include <functional>
#include <cstdio>

ZArchiveReader::ZArchiveReader(CB_ReadInputData cbReadInputData, void* ctx)
    : m_cbReadInputData(cbReadInputData)
    , m_cbCtx(ctx)
{
}

ZArchiveReader::~ZArchiveReader()
{
}

bool ZArchiveReader::Initialize()
{
    printf("Reading footer\n");
    // Read footer from end of file
    ReadData(&m_footer, -sizeof(_ZARCHIVE::Footer), sizeof(_ZARCHIVE::Footer));
    _ZARCHIVE::Footer::Deserialize(&m_footer, &m_footer);

    // Verify magic number and version
    if (m_footer.magic != _ZARCHIVE::Footer::kMagic || m_footer.version != _ZARCHIVE::Footer::kVersion1)
        return false;

    printf("Reading sections\n");
    // Read sections
    if (!ReadFileTree() || !ReadNameTable() || !ReadOffsetRecords())
        return false;

    return true;
}

bool ZArchiveReader::ReadFileTree()
{
    printf("Reading file tree section\n");
    // Read file tree section
    m_fileTree.resize(m_footer.sectionFileTree.size / sizeof(_ZARCHIVE::FileDirectoryEntry));
    ReadData(m_fileTree.data(), m_footer.sectionFileTree.offset, m_footer.sectionFileTree.size);

    // Deserialize entries
    _ZARCHIVE::FileDirectoryEntry::Deserialize(m_fileTree.data(), m_fileTree.size(), m_fileTree.data());

    return true;
}

bool ZArchiveReader::ReadNameTable()
{
    printf("Reading name table section\n");
    // Read name table section
    std::vector<uint8_t> nameData(m_footer.sectionNames.size);
    ReadData(nameData.data(), m_footer.sectionNames.offset, m_footer.sectionNames.size);

    // Parse names
    size_t offset = 0;
    while (offset < nameData.size())
    {
        // Read name length
        size_t nameLength;
        if (nameData[offset] & 0x80)
        {
            // Extended 2-byte header
            if (offset + 1 >= nameData.size()) {
                printf("Invalid name table: truncated extended header at offset %zu\n", offset);
                return false;
            }
            nameLength = ((nameData[offset] & 0x7F) | (nameData[offset + 1] << 7));
            offset += 2;
        }
        else
        {
            // Single byte header
            nameLength = nameData[offset];
            offset += 1;
        }

        // Validate name length
        if (offset + nameLength > nameData.size()) {
            printf("Invalid name table: name length %zu exceeds remaining data at offset %zu\n", nameLength, offset);
            return false;
        }

        // Read name
        printf("Reading name at offset %zu with length %zu\n", offset, nameLength);
        m_nameTable.emplace_back(reinterpret_cast<char*>(&nameData[offset]), nameLength);
        offset += nameLength;
    }

    printf("Read %zu names from name table\n", m_nameTable.size());
    return true;
}

bool ZArchiveReader::ReadOffsetRecords()
{
    printf("Reading offset records section\n");
    // Read offset records section
    m_offsetRecords.resize(m_footer.sectionOffsetRecords.size / sizeof(_ZARCHIVE::CompressionOffsetRecord));
    ReadData(m_offsetRecords.data(), m_footer.sectionOffsetRecords.offset, m_footer.sectionOffsetRecords.size);

    // Deserialize records
    _ZARCHIVE::CompressionOffsetRecord::Deserialize(m_offsetRecords.data(), m_offsetRecords.size(), m_offsetRecords.data());

    return true;
}

std::vector<ZArchiveReader::FileInfo> ZArchiveReader::ListFiles()
{
    printf("Building file list\n");
    std::vector<FileInfo> files;
    
    // Recursive lambda to process directory entries
    std::function<void(const _ZARCHIVE::FileDirectoryEntry&, const std::string&)> processEntry = 
        [&](const _ZARCHIVE::FileDirectoryEntry& entry, const std::string& parentPath) {
            uint32_t nameOffset = entry.GetNameOffset();
            std::string name;
            
            if (nameOffset == 0x7FFFFFFF) {
                name = "";
            } else if (nameOffset >= m_nameTable.size()) {
                printf("Invalid name offset: %u (max: %zu)\n", nameOffset, m_nameTable.size());
                return;
            } else {
                name = m_nameTable[nameOffset];
            }

            std::string fullPath = parentPath.empty() ? name : parentPath + "/" + name;
            printf("Processing entry: %s (isFile: %d)\n", fullPath.c_str(), entry.IsFile());

            if (entry.IsFile())
            {
                files.push_back({
                    fullPath,
                    entry.GetFileSize(),
                    entry.GetFileOffset()
                });
            }
            else
            {
                // Process directory entries
                for (uint32_t i = 0; i < entry.directoryRecord.count; i++)
                {
                    uint32_t childIndex = entry.directoryRecord.nodeStartIndex + i;
                    if (childIndex >= m_fileTree.size()) {
                        printf("Invalid child index: %u (max: %zu)\n", childIndex, m_fileTree.size());
                        continue;
                    }
                    processEntry(m_fileTree[childIndex], fullPath);
                }
            }
        };

    processEntry(m_fileTree[0], "");
    printf("Found %zu files\n", files.size());
    return files;
}

bool ZArchiveReader::ExtractFile(const char* path, const char* outputPath)
{
    printf("Extracting file: %s to %s\n", path, outputPath);
    // Find file entry
    const _ZARCHIVE::FileDirectoryEntry* fileEntry = nullptr;
    
    // Recursive lambda to find file entry
    std::function<const _ZARCHIVE::FileDirectoryEntry*(const _ZARCHIVE::FileDirectoryEntry&, const std::string&)> findEntry = 
        [&](const _ZARCHIVE::FileDirectoryEntry& entry, const std::string& remainingPath) -> const _ZARCHIVE::FileDirectoryEntry* {
            uint32_t nameOffset = entry.GetNameOffset();
            std::string name;
            
            if (nameOffset == 0x7FFFFFFF) {
                name = "";
            } else if (nameOffset >= m_nameTable.size()) {
                printf("Invalid name offset: %u (max: %zu)\n", nameOffset, m_nameTable.size());
                return nullptr;
            } else {
                name = m_nameTable[nameOffset];
            }
            
            if (entry.IsFile())
            {
                if (name == remainingPath)
                    return &entry;
                return nullptr;
            }

            // Check if this directory is part of the path
            if (remainingPath.compare(0, name.length(), name) != 0)
                return nullptr;

            // Skip directory name and separator
            std::string subPath = remainingPath.substr(name.empty() ? 0 : name.length() + 1);
            
            // Search directory entries
            for (uint32_t i = 0; i < entry.directoryRecord.count; i++)
            {
                uint32_t childIndex = entry.directoryRecord.nodeStartIndex + i;
                if (childIndex >= m_fileTree.size()) {
                    printf("Invalid child index: %u (max: %zu)\n", childIndex, m_fileTree.size());
                    continue;
                }
                if (auto result = findEntry(m_fileTree[childIndex], subPath))
                    return result;
            }

            return nullptr;
        };

    fileEntry = findEntry(m_fileTree[0], path);
    if (!fileEntry)
        return false;

    // Create output file
    std::ofstream outFile(outputPath, std::ios::binary);
    if (!outFile)
        return false;

    // Prepare decompression
    m_decompressBuffer.resize(_ZARCHIVE::COMPRESSED_BLOCK_SIZE);
    std::vector<uint8_t> compressedBuffer(_ZARCHIVE::COMPRESSED_BLOCK_SIZE);
    uint64_t remainingSize = fileEntry->GetFileSize();
    uint64_t currentOffset = fileEntry->GetFileOffset();

    // Extract file data
    while (remainingSize > 0)
    {
        // Find offset record for current block
        size_t blockIndex = currentOffset / _ZARCHIVE::COMPRESSED_BLOCK_SIZE;
        size_t recordIndex = blockIndex / _ZARCHIVE::ENTRIES_PER_OFFSETRECORD;
        size_t offsetIndex = blockIndex % _ZARCHIVE::ENTRIES_PER_OFFSETRECORD;

        if (recordIndex >= m_offsetRecords.size()) {
            printf("Invalid record index: %zu (max: %zu)\n", recordIndex, m_offsetRecords.size());
            return false;
        }

        // Get compressed block info
        uint64_t compressedOffset = m_offsetRecords[recordIndex].baseOffset;
        for (size_t i = 0; i < offsetIndex; i++)
            compressedOffset += m_offsetRecords[recordIndex].size[i] + 1;
        
        uint32_t compressedSize = m_offsetRecords[recordIndex].size[offsetIndex] + 1;

        // Read compressed block
        ReadData(compressedBuffer.data(), compressedOffset, compressedSize);

        // Decompress block
        size_t decompressedSize = ZSTD_decompress(
            m_decompressBuffer.data(), _ZARCHIVE::COMPRESSED_BLOCK_SIZE,
            compressedBuffer.data(), compressedSize
        );

        if (ZSTD_isError(decompressedSize))
        {
            // If decompression failed, the block might be stored uncompressed
            decompressedSize = compressedSize;
            memcpy(m_decompressBuffer.data(), compressedBuffer.data(), decompressedSize);
        }

        // Write decompressed data
        size_t bytesToWrite = std::min((uint64_t)decompressedSize, remainingSize);
        outFile.write(reinterpret_cast<char*>(m_decompressBuffer.data()), bytesToWrite);

        remainingSize -= bytesToWrite;
        currentOffset += _ZARCHIVE::COMPRESSED_BLOCK_SIZE;
    }

    return true;
}

void ZArchiveReader::ReadData(void* data, size_t offset, size_t length)
{
    m_cbReadInputData(data, offset, length, m_cbCtx);
}
