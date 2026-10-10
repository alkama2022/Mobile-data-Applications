import 'package:flutter/material.dart';
import '../account_store.dart';
import '../config.dart';
import '../format.dart';
import '../models.dart';
import '../purchase_data.dart';
import '../services/vtu_service.dart';
import '../theme.dart';
import '../widgets.dart';

class BulkDispatchScreen extends StatefulWidget {
  const BulkDispatchScreen({super.key});

  @override
  State<BulkDispatchScreen> createState() => _BulkDispatchScreenState();
}

class _BulkDispatchScreenState extends State<BulkDispatchScreen> {
  ServiceKind kind = ServiceKind.airtime;
  ProviderDef? provider;
  Product? product;
  final recipientsCtrl = TextEditingController();
  final amountCtrl = TextEditingController(text: '100');
  bool running = false;
  double progress = 0;
  List<String> results = [];

  final _phone = RegExp(r'^(?:\+234|234|0)[789][01]\d{8}$');

  List<ProviderDef> get _providers => providersByKind[kind] ?? [];
  List<String> get numbers => recipientsCtrl.text
      .split(RegExp(r'[\n,;]+'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
  List<String> get valid => numbers.where((n) => _phone.hasMatch(n.replaceAll(RegExp(r'[\s()-]'), ''))).toList();
  int get perKobo => kind == ServiceKind.data ? (product?.priceKobo ?? 0) : ((int.tryParse(amountCtrl.text.replaceAll(RegExp(r'\D'), '')) ?? 0) * 100);
  int get totalKobo => perKobo * valid.length;

  @override
  void initState() {
    super.initState();
    provider = _providers.isNotEmpty ? _providers.first : null;
    if (kind == ServiceKind.data && provider?.products != null && provider!.products!.isNotEmpty) {
      product = provider!.products!.first;
    }
  }

  Future<void> _run() async {
    if (provider == null || valid.isEmpty || perKobo < 10000) return;
    final user = AppConfig.client.auth.currentUser;
    if (user == null) return;
    if (accountStore.walletBalance < totalKobo && AppConfig.useEdge) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Insufficient wallet balance')));
      return;
    }
    setState(() {
      running = true;
      progress = 0;
      results = [];
    });
    final batch = generateReference();
    var ok = 0;
    for (var i = 0; i < valid.length; i++) {
      final to = valid[i];
      try {
        if (AppConfig.useEdge) {
          await VtuService.pay(
            kind: kind.dbValue,
            title: 'Bulk ${product?.name ?? kind.shortTitle}',
            recipient: to,
            amountKobo: perKobo,
            reference: '$batch-${(i + 1).toString().padLeft(3, '0')}',
            provider: provider!.name,
            vtpass: {
              'serviceID': VtpassMapping.serviceIDFor(kind.dbValue, provider!.id),
              'billersCode': to,
              'phone': to,
              if (product != null) 'variation_code': product!.id,
            },
            extraMetadata: {'bulk': true, 'batch': batch},
          );
        } else {
          await AppConfig.client.from('transactions').insert({
            'user_id': user.id,
            'kind': kind.dbValue,
            'title': 'Bulk ${product?.name ?? kind.shortTitle}',
            'recipient': to,
            'amount_kobo': perKobo,
            'reference': '$batch-${(i + 1).toString().padLeft(3, '0')}',
            'provider': provider!.name,
            'status': 'success',
            'metadata': {'bulk': true, 'batch': batch},
          });
        }
        ok++;
        results.add('✓ $to');
      } catch (e) {
        results.add('✗ $to — ${e.toString().replaceFirst('Exception: ', '')}');
      }
      setState(() => progress = (i + 1) / valid.length);
    }
    await accountStore.refresh();
    if (mounted) {
      setState(() => running = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Done: $ok/${valid.length} sent · Batch $batch')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bulk dispatch')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const InfoBanner(message: 'Paste up to 100 numbers. One charge per recipient. Failed sends are skipped, successes are kept.'),
          const SizedBox(height: 12),
          SegmentedButton<ServiceKind>(
            segments: const [
              ButtonSegment(value: ServiceKind.airtime, label: Text('Airtime'), icon: Icon(Icons.smartphone_rounded)),
              ButtonSegment(value: ServiceKind.data, label: Text('Data'), icon: Icon(Icons.wifi_rounded)),
            ],
            selected: {kind},
            onSelectionChanged: (s) {
              setState(() {
                kind = s.first;
                provider = (providersByKind[kind] ?? []).isNotEmpty ? providersByKind[kind]!.first : null;
                product = provider?.products?.isNotEmpty == true ? provider!.products!.first : null;
              });
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ProviderDef>(
            initialValue: provider,
            items: _providers.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
            onChanged: (v) => setState(() {
              provider = v;
              product = v?.products?.isNotEmpty == true ? v!.products!.first : null;
            }),
            decoration: const InputDecoration(labelText: 'Network'),
          ),
          const SizedBox(height: 12),
          if (kind == ServiceKind.data)
            DropdownButtonFormField<Product>(
              initialValue: product,
              items: (provider?.products ?? []).map((p) => DropdownMenuItem(value: p, child: Text('${p.name} · ${formatNaira(p.priceKobo).replaceAll('.00', '')}'))).toList(),
              onChanged: (v) => setState(() => product = v),
              decoration: const InputDecoration(labelText: 'Data plan'),
            )
          else
            TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount per number (₦)'), onChanged: (_) => setState(() {})),
          const SizedBox(height: 12),
          TextField(
            controller: recipientsCtrl,
            maxLines: 6,
            keyboardType: TextInputType.multiline,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Recipients (one per line or comma)',
              hintText: '0803...\n0805...',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${valid.length}/${numbers.length} valid · ${formatNaira(totalKobo).replaceAll('.00', '')} total',
            style: TextStyle(color: numbers.isNotEmpty && valid.length != numbers.length ? AppColors.destructive : AppColors.mutedForeground, fontWeight: FontWeight.w700, fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (running) LinearProgressIndicator(value: progress),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity, height: 54,
            child: FilledButton.icon(
              icon: const Icon(Icons.send_rounded),
              label: Text(running ? 'Sending ${(progress * valid.length).round()}/${valid.length}…' : 'Send to ${valid.length} numbers'),
              onPressed: (running || valid.isEmpty) ? null : _run,
            ),
          ),
          if (results.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Results', style: displayStyleOf(context,size: 16)),
            const SizedBox(height: 8),
            ...results.map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(r, style: TextStyle(fontSize: 12, color: r.startsWith('✓') ? AppColors.success : AppColors.destructive)),
                )),
          ],
        ],
      ),
    );
  }
}
