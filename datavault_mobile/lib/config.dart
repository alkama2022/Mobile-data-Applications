import 'package:supabase_flutter/supabase_flutter.dart';

class AppConfig {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://rbprvlhhsbnccaazgbnz.supabase.co',
  );
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_laNqt1nLUjN8pCgtcZkh6g_kPfGWoqa',
  );

  static SupabaseClient get client => Supabase.instance.client;

  /// When true the app calls Supabase Edge Functions (VTpass/Paystack).
  /// Run with `--dart-define=USE_EDGE=true` after `supabase functions deploy`.
  /// Defaults to false so the demo still works without backend secrets.
  static const useEdge = bool.fromEnvironment('USE_EDGE', defaultValue: false);
}
