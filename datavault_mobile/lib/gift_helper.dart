import 'package:url_launcher/url_launcher.dart';
import '../format.dart';

String giftMessage(Map<String, dynamic> tx) {
  final title = tx['title']?.toString() ?? 'airtime';
  final amount = formatNaira(tx['amount_kobo'] as int? ?? 0).replaceAll('.00', '');
  final ref = tx['reference']?.toString() ?? '';
  final meta = tx['metadata'];
  String tokenPart = '';
  if (meta is Map) {
    final t = meta['token'] ?? meta['pin'];
    if (t is String && t.isNotEmpty) tokenPart = '\nToken/PIN: $t';
  }
  return 'You received $title ($amount) via DataVault! 🎁\nRecipient: ${tx['recipient']}$tokenPart\nRef: $ref';
}

String requestMessage({required String kind, required String amountNaira, required String phone, String? name}) {
  final who = (name ?? '').trim().isEmpty ? '' : ' from ${name!.trim()}';
  return 'Hi! Please send me $kind (₦$amountNaira) to $phone$who via DataVault 🙏\nYou can pay in 1 tap if you have the app.';
}

String requestLink({required String kind, required String recipient, String? provider, String? amount}) {
  final q = <String, String>{
    'recipient': recipient,
    if (provider != null && provider.isNotEmpty) 'provider': provider,
    if (amount != null && amount.isNotEmpty) 'amount': amount,
  };
  final qs = q.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
  return 'datavault:/app/services/$kind${qs.isEmpty ? '' : '?$qs'}';
}

Future<void> shareViaWhatsApp(String text) async {
  final url = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
  await launchUrl(url, mode: LaunchMode.externalApplication);
}

Future<void> shareGift(Map<String, dynamic> tx) => shareViaWhatsApp(giftMessage(tx));
