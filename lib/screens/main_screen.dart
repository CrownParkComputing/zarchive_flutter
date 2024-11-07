import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'dart:developer' as developer;
import '../services/zarchive_service.dart';
import '../services/settings_service.dart';
import '../widgets/archive_explorer.dart';
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final ZArchiveService _archiveService = ZArchiveService();
  String? _currentArchivePath;
  double _progress = 0.0;
  bool _isProcessing = false;

  Future<void> _createArchive() async {
    try {
      final settings = Provider.of<SettingsService>(context, listen: false);
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Directory to Archive',
        initialDirectory: settings.getDefaultCreatePath(),
      );
      if (result == null) return;

      final saveResult = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Archive As',
        fileName: 'archive.zar',
      );
      if (saveResult == null) return;

      setState(() {
        _isProcessing = true;
        _progress = 0.0;
      });

      await _archiveService.createArchive(
        result, 
        saveResult,
        (current, total) {
          setState(() {
            _progress = current / total;
          });
        },
      );

      developer.log('Archive created successfully: $saveResult', 
        name: 'ZArchive', 
        error: 'Input directory: $result'
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Archive created successfully')),
        );
      }
    } catch (e) {
      developer.log('Error creating archive', 
        name: 'ZArchive', 
        error: e.toString()
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating archive: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _progress = 0.0;
        });
      }
    }
  }

  Future<void> _extractArchive() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zar'],
      );
      if (result == null) return;

      final settings = Provider.of<SettingsService>(context, listen: false);
      final extractPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Extract Location',
        initialDirectory: settings.getDefaultExtractPath(),
      );
      if (extractPath == null) return;

      setState(() {
        _isProcessing = true;
        _progress = 0.0;
      });

      final entries = await _archiveService.extractArchive(
        result.files.single.path!, 
        extractPath,
        (current, total) {
          setState(() {
            _progress = current / total;
          });
        },
      );
      
      developer.log('Archive extracted successfully', 
        name: 'ZArchive', 
        error: 'Extracted ${entries.length} entries to $extractPath'
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Archive extracted successfully (${entries.length} files)')),
        );
      }
    } catch (e) {
      developer.log('Error extracting archive', 
        name: 'ZArchive', 
        error: e.toString()
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error extracting archive: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _progress = 0.0;
        });
      }
    }
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  @override
  void dispose() {
    _archiveService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ZArchive'),
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder),
            onPressed: _isProcessing ? null : _createArchive,
            tooltip: 'Create Archive',
          ),
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _isProcessing ? null : _extractArchive,
            tooltip: 'Extract Archive',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _isProcessing ? null : _openSettings,
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Stack(
        children: [
          _currentArchivePath == null
              ? const Center(child: Text('No archive opened'))
              : ArchiveExplorer(archivePath: _currentArchivePath!),
          if (_isProcessing)
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LinearProgressIndicator(value: _progress),
                      const SizedBox(height: 8),
                      Text('${(_progress * 100).toStringAsFixed(1)}%'),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
