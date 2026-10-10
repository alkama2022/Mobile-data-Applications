import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Builds a pre-filled purchase URL for 1-tap repeat + gift links.
String repeatUri(Map<String, dynamic> tx) {
  final kind = (tx['kind']?.toString() ?? 'airtime');
  final meta = tx['metadata'];
  final metaMap = meta is Map ? Map<String, dynamic>.from(meta) : <String, dynamic>{};
  final q = <String, String>{
    if ((tx['recipient']?.toString() ?? '').isNotEmpty) 'recipient': tx['recipient'].toString(),
    if ((metaMap['providerId']?.toString() ?? '').isNotEmpty) 'provider': metaMap['providerId'].toString(),
    if ((metaMap['productId']?.toString() ?? '').isNotEmpty) 'product': metaMap['productId'].toString(),
    if ((tx['amount_kobo'] as int? ?? 0) > 0) 'amount': ((tx['amount_kobo'] as int) ~/ 100).toString(),
  };
  final qs = q.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
  return '/app/services/$kind${qs.isEmpty ? '' : '?$qs'}';
}

void repeatTransaction(BuildContext context, Map<String, dynamic> tx) {
  if ((tx['kind']?.toString() ?? '') == 'wallet_funding') return;
  context.push(repeatUri(tx));
}
