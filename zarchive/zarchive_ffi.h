#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>
#include <stddef.h>

// Forward declare the C++ classes
#ifdef __cplusplus
class ZArchiveWriter;
typedef ZArchiveWriter* ZArchiveWriter_t;
class ZArchiveReader;
typedef ZArchiveReader* ZArchiveReader_t;
#else
typedef struct ZArchiveWriter_t* ZArchiveWriter_t;
typedef struct ZArchiveReader_t* ZArchiveReader_t;
#endif

// Writer callback function types
typedef void (*NewOutputFileCb)(int32_t partIndex, void* ctx);
typedef void (*WriteOutputDataCb)(const void* data, size_t length, void* ctx);
typedef void (*ReadInputDataCb)(void* data, size_t offset, size_t length, void* ctx);

// Writer functions
ZArchiveWriter_t zarchive_writer_create(NewOutputFileCb newFileCb, WriteOutputDataCb writeDataCb, void* ctx);
void zarchive_writer_destroy(ZArchiveWriter_t writer);
int zarchive_writer_start_file(ZArchiveWriter_t writer, const char* path);
void zarchive_writer_append_data(ZArchiveWriter_t writer, const void* data, size_t size);
int zarchive_writer_make_dir(ZArchiveWriter_t writer, const char* path, int recursive);
void zarchive_writer_finalize(ZArchiveWriter_t writer);

// File info structure
typedef struct {
    const char* path;
    uint64_t size;
    uint64_t offset;
} ZArchiveFileInfo;

typedef struct {
    ZArchiveFileInfo* files;
    size_t count;
} ZArchiveFileList;

// Reader functions
ZArchiveReader_t zarchive_reader_create(ReadInputDataCb readDataCb, void* ctx);
void zarchive_reader_destroy(ZArchiveReader_t reader);
int zarchive_reader_initialize(ZArchiveReader_t reader);
ZArchiveFileList* zarchive_reader_list_files(ZArchiveReader_t reader);
void zarchive_file_list_free(ZArchiveFileList* list);
int zarchive_reader_extract_file(ZArchiveReader_t reader, const char* path, const char* outputPath);

#ifdef __cplusplus
}
#endif
