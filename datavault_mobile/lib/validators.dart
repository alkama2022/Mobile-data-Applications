/// Shared input validators — single source of truth for phone numbers.
library;

/// Nigerian mobile numbers: 0803..., +234803..., 234803...
final RegExp nigerianPhonePattern =
    RegExp(r'^(?:\+234|234|0)[789][01]\d{8}$');

String _digitsOnly(String v) => v.replaceAll(RegExp(r'[\s()\-]'), '');

bool isValidNigerianPhone(String input) =>
    nigerianPhonePattern.hasMatch(_digitsOnly(input));

bool isValidGenericRecipient(String input, {int minLength = 6}) =>
    input.trim().length >= minLength;
