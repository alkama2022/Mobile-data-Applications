import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppConfig {
  // These MUST be supplied at build time via --dart-define.
  // Never add a defaultValue here; validateConfiguration() fails fast when
  // these values are missing.
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static SupabaseClient get client => Supabase.instance.client;

  /// When true the app calls Supabase Edge Functions (VTpass / Paystack).
  /// Always true in release builds — deploy all functions before releasing.
  /// In debug builds defaults to false so the UI can be explored without secrets.
  static const bool useEdge = bool.fromEnvironment(
    'USE_EDGE',
    defaultValue: false,
  );

  /// Validates required compile-time values before initializing Supabase.
  static void validateConfiguration() {
    if (supabaseUrl.isEmpty) {
      throw StateError(
        '\n\nSUPABASE_URL is empty.\n'
        'Build with: flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co '
        '--dart-define=SUPABASE_ANON_KEY=sb_publishable_xxx\n',
      );
    }
    if (supabaseAnonKey.isEmpty) {
      throw StateError(
        '\n\nSUPABASE_ANON_KEY is empty.\n'
        'Build with: flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co '
        '--dart-define=SUPABASE_ANON_KEY=sb_publishable_xxx\n',
      );
    }
    if (kReleaseMode && !useEdge) {
      throw StateError(
        '\n\nUSE_EDGE=false in a RELEASE build.\n'
        'Deploy Edge Functions first, then rebuild with --dart-define=USE_EDGE=true\n',
      );
    }
  }
}
