import '../config.dart';

/// Paystack wallet funding via Edge Functions.
/// init() returns {authorization_url, access_code, reference}.
/// The actual wallet credit happens in `paystack-webhook` after verification,
/// so the app never trusts client-side success callbacks.
class PaystackService {
  static Future<Map<String, dynamic>> init({
    required String email,
    required int amountKobo,
    required String reference,
  }) async {
    final res = await AppConfig.client.functions.invoke(
      'paystack-init',
      body: {'email': email, 'amount_kobo': amountKobo, 'reference': reference},
    );
    final data = Map<String, dynamic>.from(res.data as Map);
    if (data['ok'] != true) {
      throw Exception(data['message'] ?? 'Could not start payment');
    }
    return Map<String, dynamic>.from(data['data'] as Map);
  }
}
