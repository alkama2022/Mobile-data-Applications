import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'config.dart';
import 'theme.dart';
import 'theme_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );
  runApp(const DataVaultApp());
}

class DataVaultApp extends StatefulWidget {
  const DataVaultApp({super.key});

  @override
  State<DataVaultApp> createState() => _DataVaultAppState();
}

class _DataVaultAppState extends State<DataVaultApp> {
  @override
  void initState() {
    super.initState();
    themeStore.addListener(_onThemeChange);
  }

  void _onThemeChange() => setState(() {});

  @override
  void dispose() {
    themeStore.removeListener(_onThemeChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'DataVault',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(dark: false),
      darkTheme: buildTheme(dark: true),
      themeMode: themeStore.mode,
      routerConfig: appRouter,
    );
  }
}
