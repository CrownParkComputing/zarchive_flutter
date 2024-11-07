import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/main_screen.dart';
import 'services/settings_service.dart';
import 'providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final settings = SettingsService();
  await settings.initialize();
  
  runApp(
    MultiProvider(
      providers: [
        Provider<SettingsService>.value(value: settings),
        ChangeNotifierProvider(create: (context) => ThemeProvider(settings)),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'ZArchive',
          theme: themeProvider.theme,
          home: const MainScreen(),
        );
      },
    );
  }
}
