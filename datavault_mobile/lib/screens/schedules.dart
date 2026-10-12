import 'package:flutter/material.dart';
import '../config.dart';
import '../format.dart';
import '../models.dart';
import '../purchase_data.dart';
import '../services/schedule_service.dart';
import '../theme.dart';
import '../widgets.dart';

class SchedulesScreen extends StatefulWidget {
  const SchedulesScreen({super.key});

  @override
  State<SchedulesScreen> createState() => _SchedulesScreenState();
}

class _SchedulesScreenState extends State<SchedulesScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _items = await ScheduleService.fetch();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _runDue() async {
    final n = await ScheduleService.runDue();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(n == 0 ? 'Nothing due yet' : 'Ran $n scheduled payment${n > 1 ? 's' : ''}')));
    _load();
  }

  void _openCreate() {
    showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => const _ScheduleForm())
        .then((created) => created == true ? _load() : null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Schedules & auto-buy')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New schedule'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            InfoBanner(
              message: AppConfig.useEdge
                  ? 'Due schedules debit your wallet and pay via VTpass.'
                  : 'Demo mode: due schedules record success rows. Deploy vtu-pay for live debit.',
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity, height: 48,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Run due now'),
                onPressed: _runDue,
              ),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
            else if (_items.isEmpty)
              Container(
                decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                child: const StateView(
                  icon: Icons.schedule_rounded,
                  title: 'No schedules yet',
                  description: 'Auto-buy data, airtime or pay electricity on daily/weekly/monthly.',
                ),
              )
            else
              ..._items.map((s) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${s['provider'] ?? s['kind']} · ${s['recipient']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(
                          '${formatNaira(s['amount_kobo'] as int? ?? 0).replaceAll('.00', '')} · ${(s['frequency'] ?? '').toString()} · next ${formatDate(s['next_run_at']?.toString() ?? '')}',
                          style: const TextStyle(color: AppColors.mutedForeground, fontSize: 12),
                        ),
                      ])),
                      Switch(
                        value: (s['active'] as bool? ?? true),
                        onChanged: (v) async {
                          await ScheduleService.toggle(s['id'].toString(), v);
                          _load();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.destructive),
                        onPressed: () async {
                          await ScheduleService.remove(s['id'].toString());
                          _load();
                        },
                      ),
                    ]),
                  )),
          ],
        ),
      ),
    );
  }
}

class _ScheduleForm extends StatefulWidget {
  const _ScheduleForm();

  @override
  State<_ScheduleForm> createState() => _ScheduleFormState();
}

class _ScheduleFormState extends State<_ScheduleForm> {
  ServiceKind kind = ServiceKind.data;
  ProviderDef? provider;
  Product? product;
  final recipient = TextEditingController();
  final amountCtrl = TextEditingController();
  String frequency = 'monthly';
  DateTime nextRun = DateTime.now().add(const Duration(days: 1));
  bool saving = false;

  List<ProviderDef> get _providers => providersByKind[kind] ?? [];
  List<Product> get _products => provider?.products ?? [];
  bool get _needsProduct =>
      kind == ServiceKind.data ||
      kind == ServiceKind.cable ||
      kind == ServiceKind.education ||
      kind == ServiceKind.internet;

  @override
  void initState() {
    super.initState();
    _resetProvider();
  }

  void _resetProvider() {
    provider = _providers.isNotEmpty ? _providers.first : null;
    product = _products.isNotEmpty ? _products.first : null;
  }

  int get _amountKobo =>
      _needsProduct && product != null
          ? product!.priceKobo
          : (int.tryParse(amountCtrl.text.replaceAll(RegExp(r'\D'), '')) ?? 0) *
              100;

  Future<void> _save() async {
    if (recipient.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a recipient / ID')));
      return;
    }
    if (provider == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Select a provider')));
      return;
    }
    if (_amountKobo < 10000) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Amount must be at least ₦100')));
      return;
    }
    setState(() => saving = true);
    try {
      await ScheduleService.create({
        'kind': kind.dbValue,
        'provider': provider!.name,
        'provider_id': provider!.id,
        if (_needsProduct && product != null) 'product_id': product!.id,
        'recipient': recipient.text.trim(),
        'amount_kobo': _amountKobo,
        'frequency': frequency,
        'next_run_at': nextRun.toUtc().toIso8601String(),
        'active': true,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('New schedule', style: displayStyleOf(context, size: 20)),
          const SizedBox(height: 12),

          // ── Service ──────────────────────────────────────────────
          DropdownButtonFormField<ServiceKind>(
            value: kind,
            items: ServiceKind.values
                .map((s) =>
                    DropdownMenuItem(value: s, child: Text(s.title)))
                .toList(),
            onChanged: (v) => setState(() {
              kind = v ?? kind;
              _resetProvider();
            }),
            decoration: const InputDecoration(labelText: 'Service'),
          ),
          const SizedBox(height: 12),

          // ── Provider ─────────────────────────────────────────────
          DropdownButtonFormField<ProviderDef>(
            value: provider,
            items: _providers
                .map((p) =>
                    DropdownMenuItem(value: p, child: Text(p.name)))
                .toList(),
            onChanged: (v) => setState(() {
              provider = v;
              product = v?.products?.isNotEmpty == true
                  ? v!.products!.first
                  : null;
            }),
            decoration: const InputDecoration(labelText: 'Provider'),
          ),
          const SizedBox(height: 12),

          // ── Product (data plans, cable packages, etc.) ───────────
          if (_needsProduct && _products.isNotEmpty) ...[
            DropdownButtonFormField<Product>(
              value: product,
              items: _products
                  .map((p) => DropdownMenuItem(
                      value: p,
                      child: Text(
                          '${p.name} · ${formatNaira(p.priceKobo).replaceAll('.00', '')}')))
                  .toList(),
              onChanged: (v) => setState(() => product = v),
              decoration: const InputDecoration(labelText: 'Plan / product'),
            ),
            const SizedBox(height: 12),
          ],

          // ── Recipient ────────────────────────────────────────────
          TextField(
            controller: recipient,
            keyboardType:
                kind == ServiceKind.airtime || kind == ServiceKind.data
                    ? TextInputType.phone
                    : TextInputType.text,
            decoration: InputDecoration(
                labelText: provider?.inputLabel ?? kind.fieldLabel,
                hintText:
                    provider?.inputPlaceholder ?? kind.fieldPlaceholder),
          ),
          const SizedBox(height: 12),

          // ── Amount (only for services without fixed products) ────
          if (!_needsProduct || _products.isEmpty) ...[
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Amount (₦)', hintText: '1000'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
          ] else ...[
            // Show the resolved amount read-only for product-based services.
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                  color: AppColors.muted,
                  borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Amount charged',
                      style: TextStyle(
                          color: AppColors.mutedForeground, fontSize: 13)),
                  Text(
                    product != null
                        ? formatNaira(product!.priceKobo)
                            .replaceAll('.00', '')
                        : '—',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Frequency ────────────────────────────────────────────
          DropdownButtonFormField<String>(
            value: frequency,
            items: const ['once', 'daily', 'weekly', 'monthly']
                .map((f) =>
                    DropdownMenuItem(value: f, child: Text(f)))
                .toList(),
            onChanged: (v) => setState(() => frequency = v ?? frequency),
            decoration: const InputDecoration(labelText: 'Repeat'),
          ),
          const SizedBox(height: 12),

          // ── First run date ───────────────────────────────────────
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('First run'),
            subtitle: Text(formatDate(nextRun.toIso8601String())),
            trailing: TextButton(
              child: const Text('Pick date'),
              onPressed: () async {
                final d = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate:
                        DateTime.now().add(const Duration(days: 365)));
                if (d != null) setState(() => nextRun = d);
              },
            ),
          ),
          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
                onPressed: saving ? null : _save,
                child: Text(saving ? 'Saving…' : 'Save schedule')),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}
