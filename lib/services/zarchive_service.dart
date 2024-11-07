import 'dart:io';
import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;
import '../models/zarchive_model.dart';
import '../ffi/zarchive_bindings.dart';

typedef ProgressCallback = void Function(int current, int total);

class ZArchiveService {
  late final ZArchiveBindings _bindings;
  static late RandomAccessFile _currentOutputFile;
  static late RandomAccessFile _currentInputFile;
  static late int _currentInputFileLength;
  
  ZArchiveService() {
    _bindings = ZArchiveBindings();
  }

  Future<void> createArchive(
    String inputPath, 
    String outputPath, 
    ProgressCallback onProgress,
  ) async {
    final inputDir = Directory(inputPath);
    if (!inputDir.existsSync()) {
      throw Exception('Input directory does not exist');
    }

    // First pass: collect files and calculate total size
    final files = await _collectFiles(inputDir);
    int totalBytes = 0;
    for (var file in files) {
      if (file is File) {
        totalBytes += await file.length();
      }
    }

    int processedBytes = 0;
    Pointer? writer;

    try {
      _currentOutputFile = await File(outputPath).open(mode: FileMode.write);

      // Create callbacks
      final newFileCb = Pointer.fromFunction<NewOutputFileCb>(_onNewFile);
      final writeDataCb = Pointer.fromFunction<WriteOutputDataCb>(_onWriteData);

      // Create writer
      writer = _bindings.createWriter(newFileCb, writeDataCb, nullptr);

      // Process all files
      for (var entity in files) {
        if (entity is! File) continue;
        
        final relativePath = path.relative(entity.path, from: inputDir.path);
        
        // Ensure parent directories exist in archive
        var parent = path.dirname(relativePath);
        if (parent != '.') {
          final parentPtr = parent.toNativeUtf8();
          final dirResult = _bindings.makeDir(writer, parentPtr, 1);
          calloc.free(parentPtr);
          if (dirResult == 0) {
            throw Exception('Failed to create directory: $parent');
          }
        }

        // Start new file
        final pathPtr = relativePath.toNativeUtf8();
        final fileResult = _bindings.startFile(writer, pathPtr);
        calloc.free(pathPtr);
        if (fileResult == 0) {
          throw Exception('Failed to start file: $relativePath');
        }

        // Write file contents
        final fileBytes = await entity.readAsBytes();
        final data = calloc<Uint8>(fileBytes.length);
        final byteList = data.asTypedList(fileBytes.length);
        byteList.setAll(0, fileBytes);
        _bindings.appendData(writer, data.cast(), fileBytes.length);
        calloc.free(data);

        processedBytes += fileBytes.length;
        onProgress(processedBytes, totalBytes);
      }

      // Finalize archive
      _bindings.finalize(writer);

    } finally {
      if (writer != null) {
        _bindings.destroyWriter(writer);
      }
      await _currentOutputFile.close();
    }
  }

  Future<List<ZArchiveEntry>> extractArchive(
    String archivePath,
    String outputPath,
    ProgressCallback onProgress,
  ) async {
    final entries = <ZArchiveEntry>[];
    Pointer? reader;
    
    try {
      // Open input file and get its length
      _currentInputFile = await File(archivePath).open(mode: FileMode.read);
      _currentInputFileLength = await _currentInputFile.length();
      
      // Create read callback
      final readDataCb = Pointer.fromFunction<ReadInputDataCb>(_onReadData);
      
      // Create reader
      reader = _bindings.createReader(readDataCb, nullptr);
      if (reader == nullptr) {
        throw Exception('Failed to create archive reader');
      }

      // Initialize reader
      final initResult = _bindings.initializeReader(reader);
      if (initResult == 0) {
        throw Exception('Failed to initialize archive reader');
      }

      // Get file list
      final fileList = _bindings.listFiles(reader);
      if (fileList == nullptr) {
        throw Exception('Failed to list archive files');
      }

      try {
        // Create output directory if it doesn't exist
        final outputDir = Directory(outputPath);
        if (!outputDir.existsSync()) {
          outputDir.createSync(recursive: true);
        }

        // Calculate total size
        int totalBytes = 0;
        for (var i = 0; i < fileList.ref.count; i++) {
          totalBytes += fileList.ref.files[i].size;
        }
        int processedBytes = 0;

        // Process each file
        for (var i = 0; i < fileList.ref.count; i++) {
          final fileInfo = fileList.ref.files[i];
          final filePath = fileInfo.path.toDartString();
          
          entries.add(ZArchiveEntry(
            name: filePath,
            isFile: true,
            size: fileInfo.size,
            offset: fileInfo.offset,
          ));

          final fullOutputPath = path.join(outputPath, filePath);
          
          // Create parent directories
          final parent = path.dirname(fullOutputPath);
          if (parent != '.') {
            Directory(parent).createSync(recursive: true);
          }

          // Extract the file
          final pathPtr = filePath.toNativeUtf8();
          final outputPathPtr = fullOutputPath.toNativeUtf8();
          final extractResult = _bindings.extractFile(reader, pathPtr, outputPathPtr);
          calloc.free(pathPtr);
          calloc.free(outputPathPtr);
          
          if (extractResult == 0) {
            throw Exception('Failed to extract file: $filePath');
          }

          processedBytes += fileInfo.size;
          onProgress(processedBytes, totalBytes);
        }
      } finally {
        _bindings.freeFileList(fileList);
      }
    } finally {
      if (reader != null) {
        _bindings.destroyReader(reader);
      }
      await _currentInputFile.close();
    }

    return entries;
  }

  // Static callback functions for FFI
  static void _onNewFile(int partIndex, Pointer<Void> ctx) {
    // No-op for now, we don't support multi-part archives
  }

  static void _onWriteData(Pointer<Void> data, int length, Pointer<Void> ctx) {
    final buffer = data.cast<Uint8>().asTypedList(length);
    _currentOutputFile.writeFromSync(buffer);
  }

  static void _onReadData(Pointer<Void> data, int offset, int length, Pointer<Void> ctx) {
    try {
      // Handle negative offsets (reading from end of file)
      final actualOffset = offset < 0 ? _currentInputFileLength + offset : offset;
      
      // Seek to the correct position
      _currentInputFile.setPositionSync(actualOffset);
      final buffer = data.cast<Uint8>().asTypedList(length);
      final bytesRead = _currentInputFile.readIntoSync(buffer);
      
      if (bytesRead != length) {
        throw Exception('Failed to read expected number of bytes');
      }
    } catch (e, stackTrace) {
      print('Error in read callback: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<List<FileSystemEntity>> _collectFiles(Directory dir) async {
    final files = <FileSystemEntity>[];
    await for (var entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        files.add(entity);
      }
    }
    return files;
  }

  void dispose() {
    // No-op
  }
}
