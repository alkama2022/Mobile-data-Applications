import '../config.dart';

class StorefrontService {
  static Future<Map<String, dynamic>?> mine() async {
    final user = AppConfig.client.auth.currentUser;
    if (user == null) return null;
    return await AppConfig.client.from('storefronts').select().eq('user_id', user.id).maybeSingle();
  }

  static Future<void> save({required String handle, required String displayName, required double markupPct, required bool active}) async {
    final user = AppConfig.client.auth.currentUser;
    if (user == null) throw Exception('Sign in again');
    final clean = handle.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
    if (clean.length < 3) throw Exception('Handle needs 3+ letters/numbers');
    await AppConfig.client.from('storefronts').upsert({
      'user_id': user.id,
      'handle': clean,
      'display_name': displayName.trim(),
      'markup_pct': markupPct,
      'active': active,
    }, onConflict: 'user_id');
  }

  static String publicLink(String handle) => 'https://datavault.ng/s/$handle';

  static String salesPitch({required String handle, required String displayName}) {
    final name = displayName.isEmpty ? handle : displayName;
    return 'Buy cheap data & airtime from $name on DataVault! ⚡\n${publicLink(handle)}\nFast delivery + WhatsApp receipt.';
  }
}
