import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../account_store.dart';
import '../format.dart';
import '../gift_helper.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

class GiftScreen extends StatefulWidget {
  const GiftScreen({super.key});

  @override
  State<GiftScreen> createState() => _GiftScreenState();
}

class _GiftScreenState extends State<GiftScreen> {
  int tab = 0;
  ServiceKind kind = ServiceKind.data;
  final phone = TextEditingController();
  final amountCtrl = TextEditingController();
  final nameCtrl = TextEditingController();

  String get _requestText => requestMessage(
        kind: kind.shortTitle,
        amountNaira: amountCtrl.text.trim().isEmpty ? '1000' : amountCtrl.text.trim(),
        phone: phone.text.trim().isEmpty ? '080...' : phone.text.trim(),
        name: nameCtrl.text.trim(),
      );

  @override
  Widget build(BuildContext context) {
    final txs = accountStore.data.transactions
        .where((t) => t['kind'] != 'wallet_funding')
        .take(10)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Gift & Request')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Gift'), icon: Icon(Icons.card_giftcard_rounded)),
              ButtonSegment(value: 1, label: Text('Request'), icon: Icon(Icons.handshake_rounded)),
            ],
            selected: {tab},
            onSelectionChanged: (s) => setState(() => tab = s.first),
          ),
          const SizedBox(height: 20),
          if (tab == 0) ...[
            const InfoBanner(message: 'Share any recent payment as a gift receipt via WhatsApp.'),
            const SizedBox(height: 12),
            if (txs.isEmpty)
              Container(
                decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                child: const StateView(icon: Icons.card_giftcard_outlined, title: 'No gifts yet', description: 'Buy airtime/data first, then share it as a gift.'),
              )
            else
              ...txs.map((t) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text('${t['recipient']} · ${formatNaira(t['amount_kobo'] as int? ?? 0).replaceAll('.00', '')}',
                            style: const TextStyle(color: AppColors.mutedForeground, fontSize: 12)),
                      ])),
                      IconButton(
                        tooltip: 'Share via WhatsApp',
                        icon: const Icon(Icons.share_rounded, color: AppColors.success),
                        onPressed: () => shareGift(t),
                      ),
                    ]),
                  )),
          ] else ...[
            const InfoBanner(message: 'Create a request, share on WhatsApp — anyone with DataVault fulfills in 1 tap.'),
            const SizedBox(height: 12),
            DropdownButtonFormField<ServiceKind>(
              initialValue: kind,
              items: ServiceKind.values.map((s) => DropdownMenuItem(value: s, child: Text(s.title))).toList(),
              onChanged: (v) => setState(() => kind = v ?? kind),
              decoration: const InputDecoration(labelText: 'What do you need?'),
            ),
            const SizedBox(height: 12),
            TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Your phone / meter / ID', hintText: '080...')),
            const SizedBox(height: 12),
            TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (₦)', hintText: '1000')),
            const SizedBox(height: 12),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Your name (optional)')),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(12)),
              child: Text(_requestText, style: const TextStyle(fontSize: 13)),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('Share on WhatsApp'),
                    onPressed: () => shareViaWhatsApp('$_requestText\n${requestLink(kind: kind.dbValue, recipient: phone.text.trim(), amount: amountCtrl.text.trim())}'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copy'),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _requestText));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request copied')));
                  },
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}
