import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _defaultCreatePath;
  String? _defaultExtractPath;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = context.read<SettingsService>();
    setState(() {
      _defaultCreatePath = settings.getDefaultCreatePath();
      _defaultExtractPath = settings.getDefaultExtractPath();
    });
  }

  Future<void> _pickDefaultCreatePath() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Default Create Path',
    );
    if (path != null) {
      final settings = context.read<SettingsService>();
      await settings.setDefaultCreatePath(path);
      setState(() {
        _defaultCreatePath = path;
      });
    }
  }

  Future<void> _pickDefaultExtractPath() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Default Extract Path',
    );
    if (path != null) {
      final settings = context.read<SettingsService>();
      await settings.setDefaultExtractPath(path);
      setState(() {
        _defaultExtractPath = path;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Theme'),
            trailing: Consumer<ThemeProvider>(
              builder: (context, themeProvider, child) => Switch(
                value: themeProvider.isDarkMode,
                onChanged: (value) => themeProvider.toggleTheme(),
              ),
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('Default Create Path'),
            subtitle: Text(_defaultCreatePath ?? 'Not set'),
            trailing: IconButton(
              icon: const Icon(Icons.folder_open),
              onPressed: _pickDefaultCreatePath,
            ),
          ),
          ListTile(
            title: const Text('Default Extract Path'),
            subtitle: Text(_defaultExtractPath ?? 'Not set'),
            trailing: IconButton(
              icon: const Icon(Icons.folder_open),
              onPressed: _pickDefaultExtractPath,
            ),
          ),
        ],
      ),
    );
  }
}
