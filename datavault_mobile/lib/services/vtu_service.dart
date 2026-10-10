import '../config.dart';

/// Calls Supabase Edge Functions that proxy VTpass with secret keys.
/// Falls back to throwing so callers can use demo-mode when USE_EDGE=false.
class VtuService {
  static Future<Map<String, dynamic>> verify({
    required String serviceID,
    required String billersCode,
  }) async {
    final res = await AppConfig.client.functions.invoke(
      'vtu-verify',
      body: {'serviceID': serviceID, 'billersCode': billersCode},
    );
    final data = Map<String, dynamic>.from(res.data as Map);
    if (data['ok'] != true) {
      throw Exception(data['message'] ?? 'Verification failed');
    }
    return Map<String, dynamic>.from(data['customer'] as Map);
  }

  static Future<Map<String, dynamic>> pay({
    required String kind,
    required String title,
    required String recipient,
    required int amountKobo,
    required String reference,
    required String provider,
    required Map<String, dynamic> vtpass,
    Map<String, dynamic>? extraMetadata,
  }) async {
    final res = await AppConfig.client.functions.invoke(
      'vtu-pay',
      body: {
        'kind': kind,
        'title': title,
        'recipient': recipient,
        'amount_kobo': amountKobo,
        'reference': reference,
        'provider': provider,
        'vtpass': vtpass,
        'metadata': extraMetadata ?? {},
      },
    );
    final data = Map<String, dynamic>.from(res.data as Map);
    if (data['ok'] != true) {
      throw Exception(data['message'] ?? 'Payment failed');
    }
    return Map<String, dynamic>.from(data['transaction'] as Map);
  }

  static Future<Map<String, dynamic>> query(String requestId) async {
    final res = await AppConfig.client.functions.invoke(
      'vtu-query',
      body: {'request_id': requestId},
    );
    return Map<String, dynamic>.from(res.data as Map);
  }
}

/// Maps the app's provider ids to VTpass serviceIDs.
/// See https://vtpass.com/documentation for full list.
class VtpassMapping {
  static String serviceIDFor(String kind, String providerId) {
    switch (kind) {
      case 'airtime':
        return '$providerId-airtime'; // mtn-airtime, airtel-airtime, glo-airtime, etisalat-airtime
      case 'data':
        return '$providerId-data';
      case 'electricity':
        return providerId; // ikedc, eko, abuja-electric, etc. — align in dashboard
      case 'cable':
        return providerId; // dstv, gotv, startimes
      case 'education':
        return providerId; // waec, jamb, etc.
      default:
        return providerId;
    }
  }
}
