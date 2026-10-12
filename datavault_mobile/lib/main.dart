import 'dart:async';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'account_store.dart';
import 'app.dart';
import 'config.dart';
import 'theme.dart';
import 'theme_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Fail fast on mis-configured builds before any UI is shown.
  AppConfig.validateConfiguration();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
  // Prime the store from on-disk cache so the home screen renders instantly.
  // Fire-and-forget — the widget tree starts while the background refresh runs.
  if (AppConfig.client.auth.currentUser != null) {
    unawaited(accountStore.loadCacheThenRefresh());
  }
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
