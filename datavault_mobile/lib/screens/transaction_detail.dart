import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import '../repeat_helper.dart';
import '../gift_helper.dart';

class TransactionDetailScreen extends StatelessWidget {
  final Map<String, dynamic> transaction;
  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final bool isCredit = transaction['kind'] == 'wallet_funding';
    final int amountKobo = transaction['amount_kobo'] as int? ?? 0;
    final String status = (transaction['status']?.toString() ?? 'success').toLowerCase();
    final String title = transaction['title']?.toString() ?? '';
    final String provider = transaction['provider']?.toString() ?? '';
    final String recipient = transaction['recipient']?.toString() ?? '';
    final String reference = transaction['reference']?.toString() ?? '';
    final String createdAt = transaction['created_at']?.toString() ?? '';
    final meta = transaction['metadata'];

    final bool isSuccess = status == 'success' || status == 'completed';

    final Color statusColor = isSuccess ? AppColors.success : AppColors.destructive;
    final Color statusBg = isSuccess ? AppColors.successSoft : const Color(0xFFFBEAE8);

    // Extract token / PIN from metadata
    final String? token = meta is Map
        ? (meta['token'] is String
            ? meta['token']
            : meta['pin'] is String
                ? meta['pin']
                : null)
        : null;

    final ServiceKind? kind = transaction['kind'] != null && transaction['kind'] != 'wallet_funding'
        ? ServiceKind.fromDb(transaction['kind'].toString())
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Transaction details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: isCredit ? AppColors.successSoft : (kind?.iconBg ?? AppColors.primarySoft),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  isCredit ? Icons.south_west_rounded : (kind?.icon ?? Icons.receipt_rounded),
                  color: isCredit ? AppColors.success : (kind?.iconFg ?? AppColors.primary),
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              Text(title, style: displayStyleOf(context, size: 20), textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(
                '${isCredit ? '+' : '−'}${formatNaira(amountKobo)}',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: isCredit ? AppColors.success : AppColors.foreground,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(999)),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.w800, fontSize: 11),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          // Token / PIN box (for electricity, education, etc.)
          if (token != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary),
                borderRadius: BorderRadius.circular(12),
                color: AppColors.primarySoft,
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  meta is Map && meta['pin'] is String ? 'PIN / TOKEN' : 'ELECTRICITY TOKEN',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 11),
                ),
                Row(children: [
                  Expanded(
                    child: Text(token, style: const TextStyle(fontFamily: 'monospace', fontSize: 22, fontWeight: FontWeight.w800)),
                  ),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: token));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Token copied')));
                    },
                    icon: const Icon(Icons.copy, color: AppColors.primary),
                  ),
                ]),
                if (meta is Map && meta['serialNumber'] is String)
                  Text('Serial: ${meta['serialNumber']}', style: const TextStyle(color: AppColors.mutedForeground, fontSize: 12)),
              ]),
            ),
            const SizedBox(height: 20),
          ],

          // Detail rows
          Text('Details', style: displayStyleOf(context, size: 16)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(children: [
              _row('Amount', formatNaira(amountKobo)),
              _row('Service', kind?.shortTitle ?? (isCredit ? 'Wallet Funding' : 'Payment')),
              if (provider.isNotEmpty) _row('Provider', provider),
              if (recipient.isNotEmpty) _row('Recipient', recipient),
              if (meta is Map && meta['meterType'] is String) _row('Meter type', meta['meterType']),
              if (meta is Map && meta['verifiedName'] is String && (meta['verifiedName'] as String).isNotEmpty)
                _row('Customer', meta['verifiedName']),
              _row('Status', status.toUpperCase()),
              _row('Date', formatDate(createdAt)),
              _rowWithCopy('Reference', reference),
            ]),
          ),
          const SizedBox(height: 20),

          // Instructions from metadata
          if (meta is Map && meta['instructions'] is String) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.highlightSoft, borderRadius: BorderRadius.circular(12)),
              child: Text(meta['instructions'].toString(), style: const TextStyle(color: AppColors.highlightForeground, fontSize: 12)),
            ),
            const SizedBox(height: 20),
          ],

          // Copy reference button
          SizedBox(
            width: double.infinity, height: 54,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.copy_all_rounded),
              label: const Text('Copy reference', style: TextStyle(fontWeight: FontWeight.w800)),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: reference));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reference copied')));
              },
            ),
          ),
          if (!isCredit) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity, height: 54,
              child: FilledButton.icon(
                icon: const Icon(Icons.repeat_rounded),
                label: const Text('Repeat this payment', style: TextStyle(fontWeight: FontWeight.w800)),
                onPressed: () => repeatTransaction(context, transaction),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity, height: 52,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.share_rounded, color: AppColors.success),
                label: const Text('Share as gift via WhatsApp', style: TextStyle(fontWeight: FontWeight.w800)),
                onPressed: () => shareGift(transaction),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _row(String k, String v) => Container(
    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(k, style: const TextStyle(color: AppColors.mutedForeground, fontSize: 13)),
      const SizedBox(width: 16),
      Flexible(child: Text(v, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
    ]),
  );

  Widget _rowWithCopy(String k, String v) => Container(
    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
    padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(k, style: const TextStyle(color: AppColors.mutedForeground, fontSize: 13)),
      Row(mainAxisSize: MainAxisSize.min, children: [
        Flexible(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.primary))),
        IconButton(
          icon: const Icon(Icons.copy, size: 14, color: AppColors.primary),
          onPressed: () => Clipboard.setData(ClipboardData(text: v)),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      ]),
    ]),
  );
}

/// Helper to push a transaction detail screen from anywhere
void pushTransactionDetail(BuildContext context, Map<String, dynamic> tx) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => TransactionDetailScreen(transaction: tx)));
}
