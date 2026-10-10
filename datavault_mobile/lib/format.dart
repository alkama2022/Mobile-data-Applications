import 'dart:math';
import 'package:intl/intl.dart';

String formatNaira(int kobo) {
  final f = NumberFormat.currency(symbol: '₦', locale: 'en_NG', decimalDigits: 2);
  return f.format(kobo / 100);
}

String formatDate(String iso) {
  try {
    return DateFormat('dd MMM yyyy, h:mm a').format(DateTime.parse(iso).toLocal());
  } catch (_) {
    return iso;
  }
}

/// Generates a unique, human-readable transaction reference like DVT-20261009-X4F8K2
String generateReference() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final rand = Random.secure();
  final suffix = List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  final date = DateFormat('yyyyMMdd').format(DateTime.now());
  return 'DVT-$date-$suffix';
}
