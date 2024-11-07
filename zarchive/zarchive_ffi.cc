#include "zarchive_ffi.h"
#include "zarchivewriter.h"
#include "zarchivereader.h"
#include <cstring>
#include <vector>
#include <cstdio>

extern "C" {

// Writer functions
ZArchiveWriter_t zarchive_writer_create(NewOutputFileCb newFileCb, WriteOutputDataCb writeDataCb, void* ctx) {
    return new ZArchiveWriter(
        reinterpret_cast<ZArchiveWriter::CB_NewOutputFile>(newFileCb),
        reinterpret_cast<ZArchiveWriter::CB_WriteOutputData>(writeDataCb),
        ctx
    );
}

void zarchive_writer_destroy(ZArchiveWriter_t writer) {
    delete writer;
}

int zarchive_writer_start_file(ZArchiveWriter_t writer, const char* path) {
    return writer->StartNewFile(path) ? 1 : 0;
}

void zarchive_writer_append_data(ZArchiveWriter_t writer, const void* data, size_t size) {
    writer->AppendData(data, size);
}

int zarchive_writer_make_dir(ZArchiveWriter_t writer, const char* path, int recursive) {
    return writer->MakeDir(path, recursive != 0) ? 1 : 0;
}

void zarchive_writer_finalize(ZArchiveWriter_t writer) {
    writer->Finalize();
}

// Reader functions
ZArchiveReader_t zarchive_reader_create(ReadInputDataCb readDataCb, void* ctx) {
    printf("Creating reader\n");
    return new ZArchiveReader(
        reinterpret_cast<ZArchiveReader::CB_ReadInputData>(readDataCb),
        ctx
    );
}

void zarchive_reader_destroy(ZArchiveReader_t reader) {
    printf("Destroying reader\n");
    delete reader;
}

int zarchive_reader_initialize(ZArchiveReader_t reader) {
    printf("Initializing reader\n");
    bool result = reader->Initialize();
    printf("Initialize result: %d\n", result);
    return result ? 1 : 0;
}

ZArchiveFileList* zarchive_reader_list_files(ZArchiveReader_t reader) {
    printf("Listing files\n");
    try {
        auto files = reader->ListFiles();
        printf("Got %zu files\n", files.size());
        
        if (files.empty()) {
            printf("No files found\n");
            return nullptr;
        }

        // Allocate file list structure
        printf("Allocating file list structure\n");
        auto* list = (ZArchiveFileList*)calloc(1, sizeof(ZArchiveFileList));
        if (!list) {
            printf("Failed to allocate file list\n");
            return nullptr;
        }

        // Allocate file array
        list->count = files.size();
        printf("Allocating file array of size %zu\n", list->count);
        list->files = (ZArchiveFileInfo*)calloc(files.size(), sizeof(ZArchiveFileInfo));
        if (!list->files) {
            printf("Failed to allocate file array\n");
            free(list);
            return nullptr;
        }

        // Copy file information
        printf("Copying file information\n");
        for (size_t i = 0; i < files.size(); i++) {
            printf("Processing file %zu: %s (size: %zu)\n", i, files[i].path.c_str(), files[i].path.length());
            
            // Allocate and copy path string
            const auto& path = files[i].path;
            size_t pathLen = path.length() + 1;
            char* pathCopy = (char*)malloc(pathLen);
            if (!pathCopy) {
                printf("Failed to allocate path string for file %zu\n", i);
                // Clean up on allocation failure
                for (size_t j = 0; j < i; j++) {
                    free((void*)list->files[j].path);
                }
                free(list->files);
                free(list);
                return nullptr;
            }
            memset(pathCopy, 0, pathLen);
            strncpy(pathCopy, path.c_str(), pathLen - 1);

            // Set file info
            list->files[i].path = pathCopy;
            list->files[i].size = files[i].size;
            list->files[i].offset = files[i].offset;
            
            printf("File %zu processed successfully: %s\n", i, list->files[i].path);
        }

        printf("File list created successfully\n");
        return list;
    } catch (const std::exception& e) {
        printf("Exception in list_files: %s\n", e.what());
        return nullptr;
    } catch (...) {
        printf("Unknown exception in list_files\n");
        return nullptr;
    }
}

void zarchive_file_list_free(ZArchiveFileList* list) {
    printf("Freeing file list\n");
    if (list) {
        if (list->files) {
            printf("Freeing %zu file entries\n", list->count);
            // Free path strings
            for (size_t i = 0; i < list->count; i++) {
                if (list->files[i].path) {
                    printf("Freeing path string %zu: %s\n", i, list->files[i].path);
                    free((void*)list->files[i].path);
                }
            }
            printf("Freeing file array\n");
            free(list->files);
        }
        printf("Freeing list structure\n");
        free(list);
    }
    printf("File list freed\n");
}

int zarchive_reader_extract_file(ZArchiveReader_t reader, const char* path, const char* outputPath) {
    printf("Extracting file: %s to %s\n", path, outputPath);
    bool result = reader->ExtractFile(path, outputPath);
    printf("Extract result: %d\n", result);
    return result ? 1 : 0;
}

}
