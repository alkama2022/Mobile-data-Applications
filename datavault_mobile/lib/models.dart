import 'package:flutter/material.dart';

enum ServiceKind {
  airtime('airtime', 'Buy airtime', 'Airtime', 'Instant top-up on every network', 'Phone number', '080 1234 5678'),
  data('data', 'Buy data', 'Data', 'Affordable bundles, delivered fast', 'Phone number', '080 1234 5678'),
  electricity('electricity', 'Pay electricity', 'Electricity', 'Prepaid and postpaid meters', 'Meter number', 'Enter meter number'),
  cable('cable', 'Pay cable TV', 'Cable TV', 'Renew your viewing subscription', 'Smartcard number', 'Enter smartcard number'),
  education('education', 'Buy exam PIN', 'Exam PINs', 'WAEC, NECO, JAMB and NABTEB products', 'Candidate or student ID', 'Enter identification number'),
  internet('internet', 'Internet bundles', 'Internet', 'Broadband plans for home and mobile', 'Account or customer ID', 'Enter account details'),
  betting('betting', 'Fund betting wallet', 'Betting', 'Top up supported gaming wallets', 'Customer ID', 'Enter customer ID');

  final String dbValue;
  final String title;
  final String shortTitle;
  final String description;
  final String fieldLabel;
  final String fieldPlaceholder;
  const ServiceKind(this.dbValue, this.title, this.shortTitle, this.description, this.fieldLabel, this.fieldPlaceholder);

  static ServiceKind? fromDbOrNull(String v) {
    for (final e in ServiceKind.values) {
      if (e.dbValue == v) return e;
    }
    return null;
  }

  /// Strict parse. Throws on unknown values so bad rows surface instead of
  /// silently rendering as airtime. Callers that need leniency use fromDbOrNull.
  static ServiceKind fromDb(String v) =>
      fromDbOrNull(v) ?? (throw ArgumentError.value(v, 'ServiceKind', 'Unknown service kind'));

  IconData get icon {
    switch (this) {
      case ServiceKind.airtime:
        return Icons.smartphone_rounded;
      case ServiceKind.data:
        return Icons.wifi_rounded;
      case ServiceKind.electricity:
        return Icons.bolt_rounded;
      case ServiceKind.cable:
        return Icons.tv_rounded;
      case ServiceKind.education:
        return Icons.school_rounded;
      case ServiceKind.internet:
        return Icons.router_rounded;
      case ServiceKind.betting:
        return Icons.emoji_events_rounded;
    }
  }

  Color get iconBg {
    switch (this) {
      case ServiceKind.airtime:
        return const Color(0xFFEAE4FA);
      case ServiceKind.data:
        return const Color(0xFFE3F4EC);
      case ServiceKind.electricity:
        return const Color(0xFFF9ECD2);
      case ServiceKind.cable:
        return const Color(0xFFDDEBFA);
      case ServiceKind.education:
        return const Color(0xFFF9E5DE);
      case ServiceKind.internet:
        return const Color(0xFFE6EEFC);
      case ServiceKind.betting:
        return const Color(0xFFE0F2E5);
    }
  }

  Color get iconFg {
    switch (this) {
      case ServiceKind.airtime:
        return const Color(0xFF6A4FD8);
      case ServiceKind.data:
        return const Color(0xFF2E9E77);
      case ServiceKind.electricity:
        return const Color(0xFFC98A1B);
      case ServiceKind.cable:
        return const Color(0xFF2F7FD1);
      case ServiceKind.education:
        return const Color(0xFFC2583A);
      case ServiceKind.internet:
        return const Color(0xFF2F6FED);
      case ServiceKind.betting:
        return const Color(0xFF2F8F57);
    }
  }
}
