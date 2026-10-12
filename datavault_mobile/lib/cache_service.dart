import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight stale-while-revalidate cache backed by SharedPreferences.
/// Stores the last good account snapshot so the home screen renders instantly
/// from disk on every cold launch while the network refresh runs in the background.
class CacheService {
  static const _walletKey = 'cache_wallet';
  static const _profileKey = 'cache_profile';
  static const _txKey = 'cache_transactions';
  static const _notifKey = 'cache_notifications';
  static const _benKey = 'cache_beneficiaries';

  // ── write ──────────────────────────────────────────────────────────────────

  static Future<void> saveAccount({
    Map<String, dynamic>? wallet,
    Map<String, dynamic>? profile,
    List<Map<String, dynamic>> transactions = const [],
    List<Map<String, dynamic>> notifications = const [],
    List<Map<String, dynamic>> beneficiaries = const [],
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (wallet != null) await prefs.setString(_walletKey, jsonEncode(wallet));
    if (profile != null) await prefs.setString(_profileKey, jsonEncode(profile));
    await prefs.setString(_txKey, jsonEncode(transactions));
    await prefs.setString(_notifKey, jsonEncode(notifications));
    await prefs.setString(_benKey, jsonEncode(beneficiaries));
  }

  // ── read ───────────────────────────────────────────────────────────────────

  static Future<CachedAccount?> loadAccount() async {
    final prefs = await SharedPreferences.getInstance();
    final profileRaw = prefs.getString(_profileKey);
    if (profileRaw == null) return null; // nothing cached yet

    return CachedAccount(
      wallet: _decodeMap(prefs.getString(_walletKey)),
      profile: _decodeMap(profileRaw),
      transactions: _decodeList(prefs.getString(_txKey)),
      notifications: _decodeList(prefs.getString(_notifKey)),
      beneficiaries: _decodeList(prefs.getString(_benKey)),
    );
  }

  /// Clears cache on logout so stale data is never shown for a different user.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_walletKey),
      prefs.remove(_profileKey),
      prefs.remove(_txKey),
      prefs.remove(_notifKey),
      prefs.remove(_benKey),
    ]);
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  static Map<String, dynamic>? _decodeMap(String? raw) {
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  static List<Map<String, dynamic>> _decodeList(String? raw) {
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }
}

class CachedAccount {
  final Map<String, dynamic>? wallet;
  final Map<String, dynamic>? profile;
  final List<Map<String, dynamic>> transactions;
  final List<Map<String, dynamic>> notifications;
  final List<Map<String, dynamic>> beneficiaries;
  const CachedAccount({
    this.wallet,
    this.profile,
    this.transactions = const [],
    this.notifications = const [],
    this.beneficiaries = const [],
  });
}
