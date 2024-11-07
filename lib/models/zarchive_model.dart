import 'dart:typed_data';

class ZArchiveEntry {
  final String name;
  final bool isFile;
  final int size;
  final int offset;

  ZArchiveEntry({
    required this.name,
    required this.isFile,
    required this.size,
    this.offset = 0,
  });
}

class ZArchiveDirectory {
  final String name;
  final List<ZArchiveEntry> entries;

  ZArchiveDirectory({
    required this.name,
    required this.entries,
  });
}
