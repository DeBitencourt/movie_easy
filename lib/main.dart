import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'core/theme/app_theme.dart';
import 'providers/catalog_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/downloads_provider.dart';
import 'views/main_layout.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(1280, 800),
      minimumSize: Size(960, 640),
      center: true,
      backgroundColor: Color(0xFF0F0F14),
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      title: 'MovieEasy',
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const MovieEasyApp());
}

class MovieEasyApp extends StatelessWidget {
  const MovieEasyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(
          create: (_) => CatalogProvider()..loadHomeCatalog(),
        ),
        ChangeNotifierProvider(
          create: (_) => DownloadsProvider()..init(),
        ),
      ],
      child: MaterialApp(
        title: 'MovieEasy',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const MainLayout(),
      ),
    );
  }
}
