import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// PIN persistence. Hash + salt live in secure storage (Keychain/Keystore).
/// The `pin_enabled` flag stays in SharedPreferences (non-sensitive).
/// Migrates legacy SharedPreferences entries once, then deletes them.
class PinStorage {
  static const hashKey = 'app_pin_hash';
  static const saltKey = 'app_pin_salt';
  static const pinEnabledKey = 'pin_enabled';

  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<String?> readHash() async {
    final secure = await _secure.read(key: hashKey);
    if (secure != null) return secure;
    // One-time migration from legacy plain prefs.
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(hashKey);
    if (legacy != null) {
      await _secure.write(key: hashKey, value: legacy);
      await prefs.remove(hashKey);
      return legacy;
    }
    return null;
  }

  static Future<String?> readSalt() async {
    final secure = await _secure.read(key: saltKey);
    if (secure != null) return secure;
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(saltKey);
    if (legacy != null) {
      await _secure.write(key: saltKey, value: legacy);
      await prefs.remove(saltKey);
      return legacy;
    }
    return null;
  }

  static Future<void> writePin(String salt, String hash) async {
    await _secure.write(key: saltKey, value: salt);
    await _secure.write(key: hashKey, value: hash);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(pinEnabledKey, true);
  }

  static Future<void> clearPin() async {
    await _secure.delete(key: hashKey);
    await _secure.delete(key: saltKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(pinEnabledKey, false);
  }

  static Future<bool> isPinEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(pinEnabledKey) ?? false;
  }
}
