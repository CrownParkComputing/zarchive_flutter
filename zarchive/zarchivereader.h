#pragma once

#include <cstdint>
#include <vector>
#include <string_view>
#include <unordered_map>

#include "zarchivecommon.h"

class ZArchiveReader {
public:
    typedef void(*CB_ReadInputData)(void* data, size_t offset, size_t length, void* ctx);

    struct FileInfo {
        std::string path;
        uint64_t size;
        uint64_t offset;
    };

    ZArchiveReader(CB_ReadInputData cbReadInputData, void* ctx);
    ~ZArchiveReader();

    bool Initialize();
    std::vector<FileInfo> ListFiles();
    bool ExtractFile(const char* path, const char* outputPath);

private:
    bool ReadFooter();
    bool ReadFileTree();
    bool ReadNameTable();
    bool ReadOffsetRecords();
    void ReadData(void* data, size_t offset, size_t length);

private:
    CB_ReadInputData m_cbReadInputData;
    void* m_cbCtx;
    _ZARCHIVE::Footer m_footer;
    std::vector<_ZARCHIVE::FileDirectoryEntry> m_fileTree;
    std::vector<std::string> m_nameTable;
    std::vector<_ZARCHIVE::CompressionOffsetRecord> m_offsetRecords;
    std::vector<uint8_t> m_decompressBuffer;
};
