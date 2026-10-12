import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../config.dart';
import '../format.dart';
import '../account_store.dart';
import '../app_logger.dart';
import '../models.dart';
import '../services/vtu_service.dart';
import '../gift_helper.dart';
import '../purchase_data.dart';
import '../validators.dart';
import '../theme.dart';
import '../widgets.dart';

enum _Stage { provider, details, product, amount, review }

List<_Stage> _stagesFor(ServiceKind kind) {
  switch (kind) {
    case ServiceKind.airtime:
    case ServiceKind.electricity:
    case ServiceKind.betting:
      return [_Stage.provider, _Stage.details, _Stage.amount, _Stage.review];
    case ServiceKind.cable:
    case ServiceKind.internet:
    case ServiceKind.education:
      return [_Stage.provider, _Stage.product, _Stage.details, _Stage.review];
    case ServiceKind.data:
      return [_Stage.provider, _Stage.details, _Stage.product, _Stage.review];
  }
}

class PurchaseScreen extends StatefulWidget {
  final String kind;
  final String? initialProviderId;
  final String? initialRecipient;
  final String? initialProductId;
  final String? initialAmountNaira;
  const PurchaseScreen({
    super.key,
    required this.kind,
    this.initialProviderId,
    this.initialRecipient,
    this.initialProductId,
    this.initialAmountNaira,
  });

  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  late final ServiceKind service;
  late final List<_Stage> stages;
  int stageIndex = 0;
  ProviderDef? provider;
  final recipient = TextEditingController();
  String meterType = 'Prepaid';
  Product? product;
  String category = 'All';
  String amount = '';
  Map<String, dynamic>? verified;
  bool verifying = false;
  bool saveBeneficiary = false;
  String search = '';
  Map<String, dynamic>? transaction;
  // Tracks the reference of the in-flight VTpass request so we can poll
  // vtu-query if the response times out and the tx stays 'pending'.
  String? _pendingReference;

  @override
  void initState() {
    super.initState();
    final parsed = ServiceKind.fromDbOrNull(widget.kind);
    if (parsed == null) {
      logError('PurchaseScreen unknown kind', widget.kind);
      service = ServiceKind.airtime;
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showAppToast(context, 'Unsupported service: ${widget.kind}');
          context.pop();
        });
      }
    } else {
      service = parsed;
    }
    stages = _stagesFor(service);
    // 1-tap repeat pre-fill
    final providers = providersByKind[service] ?? [];
    if (widget.initialProviderId != null) {
      for (final p in providers) {
        if (p.id == widget.initialProviderId) provider = p;
      }
      provider ??= providers.isNotEmpty ? providers.firstWhere(
        (p) => p.name.toLowerCase() == widget.initialProviderId!.toLowerCase(),
        orElse: () => providers.first,
      ) : null;
    }
    if (widget.initialRecipient != null) recipient.text = widget.initialRecipient!;
    if (widget.initialProductId != null && provider?.products != null) {
      for (final p in provider!.products!) {
        if (p.id == widget.initialProductId) product = p;
      }
    }
    if (widget.initialAmountNaira != null) amount = widget.initialAmountNaira!.replaceAll(RegExp(r'\D'), '');
    // Jump to review when repeat carries complete details
    if (provider != null && detailsValid) {
      final needsProduct = stages.contains(_Stage.product);
      final needsAmount = stages.contains(_Stage.amount);
      final hasValue = (needsProduct && product != null) || (needsAmount && amountValid) || (!needsProduct && !needsAmount);
      if (hasValue && !requiresVerification) {
        stageIndex = stages.length - 1;
      } else if (hasValue && requiresVerification) {
        // Still need verify step; go to details so user taps Verify
        stageIndex = stages.indexOf(_Stage.details);
      }
    }
  }

  bool get isPhone => service == ServiceKind.airtime || service == ServiceKind.data;
  bool get requiresVerification => service == ServiceKind.electricity || service == ServiceKind.cable || service == ServiceKind.betting;
  bool get detailsValid => isPhone
      ? isValidNigerianPhone(recipient.text)
      : isValidGenericRecipient(recipient.text,
          minLength: service == ServiceKind.education ? 4 : 6);
  int get totalKobo => product?.priceKobo ?? ((int.tryParse(amount) ?? 0) * 100);
  bool get amountValid => totalKobo >= 10000;

  _Stage get stage => stages[stageIndex];

  Future<void> verify() async {
    if (!detailsValid || provider == null) return;
    setState(() => verifying = true);
    try {
      if (AppConfig.useEdge) {
        final serviceID = VtpassMapping.serviceIDFor(service.dbValue, provider!.id);
        final customer = await VtuService.verify(
          serviceID: serviceID,
          billersCode: recipient.text.trim(),
        );
        setState(() {
          verified = {'name': customer['name'], 'address': customer['address'] ?? ''};
          verifying = false;
        });
        return;
      }
      // Demo fallback (no secrets configured) - debug only.
      if (kReleaseMode) {
        setState(() => verifying = false);
        if (mounted) showAppToast(context, 'Live verification not configured. Deploy Edge Functions first.');
        return;
      }
      await Future.delayed(const Duration(milliseconds: 700));
      if (recipient.text.endsWith('000')) {
        setState(() {
          verifying = false;
          verified = null;
        });
        if (mounted) showAppToast(context, 'We could not verify these details. Please check and try again.');
        return;
      }
      final suffix = recipient.text.replaceAll(RegExp(r'\D'), '');
      setState(() {
        // Demo-only placeholder names. Clearly labelled so they can never be
        // mistaken for verified VTpass data in production.
        verified = {
          'name': service == ServiceKind.electricity
              ? '[DEMO] Chinedu O. (unverified)'
              : service == ServiceKind.cable
                  ? '[DEMO] Adaeze W. (unverified)'
                  : 'Demo customer ${suffix.substring(suffix.length > 4 ? suffix.length - 4 : 0)} (unverified)',
          if (service == ServiceKind.electricity) 'address': '[DEMO] 12 Unity Crescent, Abuja',
        };
        verifying = false;
      });
    } catch (e, stack) {
      logError('PurchaseScreen.verify failed', e, stack);
      setState(() {
        verifying = false;
        verified = null;
      });
      if (mounted) showAppToast(context, e);
    }
  }

  Map<String, dynamic> _vtpassPayload() {
    final serviceID = VtpassMapping.serviceIDFor(service.dbValue, provider!.id);
    return {
      'serviceID': serviceID,
      'billersCode': recipient.text.trim(),
      'phone': recipient.text.trim(),
      if (product != null) 'variation_code': product!.id,
    };
  }

  /// Polls vtu-query every 5 s for up to 60 s when a transaction is stuck
  /// in 'pending' (e.g. Deno Edge Function timed out mid-request).
  /// Updates the local transaction map and advances to the success stage
  /// automatically when the provider confirms delivery.
  Future<void> _pollPending(String ref) async {
    const maxAttempts = 12; // 12 × 5 s = 60 s
    for (var i = 0; i < maxAttempts; i++) {
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return;
      try {
        final result = await VtuService.query(ref);
        final code = result['vtpass']?['code']?.toString() ?? '';
        if (code == '000') {
          // VTpass confirmed success — fetch the updated transaction row.
          final txRow = await AppConfig.client
              .from('transactions')
              .select()
              .eq('reference', ref)
              .maybeSingle();
          if (txRow != null && mounted) {
            setState(() {
              transaction = Map<String, dynamic>.from(txRow);
              stageIndex = stages.length + 1; // success
            });
            await accountStore.refreshWalletAndTransactions();
          }
          return;
        } else if (code.isNotEmpty && code != '000') {
          // Definitive failure — go back to review.
          if (mounted) {
            if (mounted) showAppToast(context, 'Payment failed: ${result['vtpass']?['response_description'] ?? 'Provider declined'}');
            setState(() => stageIndex = stages.length - 1);
          }
          return;
        }
        // code is empty or still pending — keep polling
      } catch (_) {
        // network hiccup — keep polling
      }
    }
    // Timed out — show a message and go back to review
    if (mounted) {
      showAppToast(context, 'Payment status unknown. Check your Activity tab in a moment.');
      setState(() => stageIndex = stages.length - 1);
      await accountStore.refreshWalletAndTransactions();
    }
  }

  Future<void> pay() async {
    if (provider == null || !amountValid) return;
    setState(() => stageIndex = stages.length); // processing
    final user = AppConfig.client.auth.currentUser;
    if (user == null) {
      if (mounted) showAppToast(context, 'Please sign in again.');
      setState(() => stageIndex = stages.length - 1);
      return;
    }
    try {
      final metadata = <String, dynamic>{
        'service': service.shortTitle,
        'providerId': provider!.id,
        if (product != null) ...{
          'productId': product!.id,
          'productName': product!.name,
          'productSubtitle': product!.subtitle,
          'expectedAmountKobo': product!.priceKobo,
        },
        if (service == ServiceKind.electricity) ...{'meterType': meterType, 'verifiedName': verified?['name'] ?? '', 'verifiedAddress': verified?['address'] ?? ''},
        if (service == ServiceKind.cable || service == ServiceKind.betting) 'verifiedName': verified?['name'] ?? '',
      };
      late final Map<String, dynamic> data;
      if (AppConfig.useEdge) {
        final ref = generateReference();
        _pendingReference = ref;
        data = await VtuService.pay(
          kind: service.dbValue,
          title: product?.name ?? service.title,
          recipient: recipient.text.trim(),
          amountKobo: totalKobo,
          reference: ref,
          provider: provider!.name,
          vtpass: _vtpassPayload(),
          extraMetadata: metadata,
        );
        _pendingReference = null;
      } else {
        if (kReleaseMode) throw Exception('Live payments not configured. Deploy vtu-pay Edge Function and rebuild with --dart-define=USE_EDGE=true.');
        data = await AppConfig.client.from('transactions').insert({
          'user_id': user.id,
          'kind': service.dbValue,
          'title': product?.name ?? service.title,
          'recipient': recipient.text.trim(),
          'amount_kobo': totalKobo,
          'reference': generateReference(),
          'provider': provider!.name,
          'status': 'success',
          'metadata': metadata,
        }).select().single();
      }
      if (saveBeneficiary && recipient.text.trim().isNotEmpty) {
        await AppConfig.client.from('beneficiaries').upsert({
          'user_id': user.id,
          'kind': service.dbValue,
          'nickname': verified?['name'] ?? provider!.shortName,
          'recipient': recipient.text.trim(),
          'provider': provider!.name,
          'provider_id': provider!.id,
        }, onConflict: 'user_id,kind,recipient');
      }
      setState(() {
        transaction = data;
        stageIndex = stages.length + 1; // success
      });
      await accountStore.refreshWalletAndTransactions();
    } catch (e, stack) {
      logError('PurchaseScreen.pay failed', e, stack);
      // If we assigned a reference but got a timeout/network error, the VTpass
      // request may have succeeded server-side. Poll to find out.
      final ref = _pendingReference;
      _pendingReference = null;
      if (ref != null && AppConfig.useEdge && mounted) {
        // Stay on the processing screen and poll instead of showing an error.
        unawaited(_pollPending(ref));
        return;
      }
      if (mounted) showAppToast(context, e);
      setState(() => stageIndex = stages.length - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (stageIndex == stages.length) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 88, height: 88, decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(999)), child: const Center(child: SizedBox(width: 40, height: 40, child: CircularProgressIndicator()))),
              const SizedBox(height: 24),
              Text('Processing payment', style: displayStyleOf(context,size: 22)),
              const SizedBox(height: 8),
              Text('Please keep this screen open while we confirm your ${service.shortTitle.toLowerCase()} purchase.', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.mutedForeground)),
              const SizedBox(height: 28),
              const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.verified_user_rounded, color: AppColors.success, size: 16), SizedBox(width: 6), Text('Secured by DataVault', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w800, fontSize: 12))]),
            ]),
          ),
        ),
      );
    }

    if (stageIndex == stages.length + 1 && transaction != null) {
      final meta = transaction!['metadata'];
      final token = meta is Map ? (meta['token'] is String ? meta['token'] : meta['pin'] is String ? meta['pin'] : null) : null;
      return Scaffold(
        appBar: AppBar(),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            Container(width: 72, height: 72, decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(999), boxShadow: [BoxShadow(color: AppColors.successSoft, spreadRadius: 10, blurRadius: 0)]), child: const Icon(Icons.check, color: Colors.white, size: 36)),
            const SizedBox(height: 20),
            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5), decoration: BoxDecoration(color: AppColors.successSoft, borderRadius: BorderRadius.circular(999)), child: const Text('PAYMENT SUCCESSFUL', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w800, fontSize: 11))),
            const SizedBox(height: 12),
            Text("You're all set", style: displayStyleOf(context,size: 26)),
            const SizedBox(height: 8),
            Text('Your ${service.shortTitle.toLowerCase()} purchase was completed.', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.mutedForeground)),
            if (token != null) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(border: Border.all(color: AppColors.primary, style: BorderStyle.solid), borderRadius: BorderRadius.circular(12), color: AppColors.primarySoft),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(meta is Map && meta['pin'] is String ? 'PIN / TOKEN' : 'ELECTRICITY TOKEN', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 11)),
                  Row(children: [
                    Expanded(child: Text(token.toString(), style: const TextStyle(fontFamily: 'monospace', fontSize: 18, fontWeight: FontWeight.w800))),
                    IconButton(onPressed: () { Clipboard.setData(ClipboardData(text: token.toString())); if (context.mounted) showAppToast(context, 'Copied'); }, icon: const Icon(Icons.copy)),
                  ]),
                  if (meta is Map && meta['serialNumber'] is String) Text('Serial: ${meta['serialNumber']}', style: const TextStyle(color: AppColors.mutedForeground, fontSize: 12)),
                ]),
              ),
            ],
            const SizedBox(height: 20),
            _receiptRow('Provider', transaction!['provider']?.toString() ?? ''),
            if (product != null) _receiptRow('Product', product!.name),
            _receiptRow('Recipient', transaction!['recipient']?.toString() ?? ''),
            _receiptRow('Amount paid', formatNaira(transaction!['amount_kobo'] as int? ?? 0)),
            _receiptRow('Reference', transaction!['reference']?.toString() ?? ''),
            _receiptRow('Date', formatDate(transaction!['created_at']?.toString() ?? '')),
            if (meta is Map && meta['instructions'] is String) ...[
              const SizedBox(height: 16),
              Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.highlightSoft, borderRadius: BorderRadius.circular(12)), child: Text(meta['instructions'].toString(), style: const TextStyle(color: AppColors.highlightForeground, fontSize: 12))),
            ],
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, height: 54, child: FilledButton(onPressed: () => context.go('/app/activity'), child: const Text('View transaction history'))),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity, height: 52,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.share_rounded),
                label: const Text('Share as gift via WhatsApp'),
                onPressed: () => shareGift(transaction!),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, height: 48, child: TextButton(onPressed: () => context.go('/app'), child: const Text('Back to home'))),
          ]),
        ),
      );
    }

    final step = stages[stageIndex];
    final currentStep = stageIndex + 1;
    final providers = providersByKind[service] ?? [];
    final displayProducts = () {
      final list = provider?.products ?? <Product>[];
      if (service != ServiceKind.data || category == 'All') return list;
      return list.where((p) => p.category == category).toList();
    }();

    return Scaffold(
      appBar: AppBar(title: Text(service.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextButton.icon(onPressed: () => stageIndex > 0 ? setState(() => stageIndex--) : context.pop(), icon: const Icon(Icons.chevron_left), label: const Text('Back')),
          Row(children: [
            Eyebrow('Step $currentStep of ${stages.length}'),
            const Spacer(),
            Text('${((currentStep / stages.length) * 100).round()}%', style: const TextStyle(color: AppColors.mutedForeground, fontWeight: FontWeight.w800, fontSize: 12)),
          ]),
          const SizedBox(height: 10),
          LinearProgressIndicator(value: currentStep / stages.length, borderRadius: BorderRadius.circular(4), backgroundColor: AppColors.muted),
          const SizedBox(height: 20),
          Text(_stepTitle(), style: displayStyleOf(context,size: 22)),
          const SizedBox(height: 6),
          Text(_stepDescription(), style: const TextStyle(color: AppColors.mutedForeground)),
          const SizedBox(height: 24),
          if (step == _Stage.provider) ...[
            TextField(onChanged: (v) => setState(() => search = v), decoration: InputDecoration(hintText: 'Search providers', prefixIcon: const Icon(Icons.search), filled: true, fillColor: AppColors.card, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.2,
              children: providers.where((p) => p.name.toLowerCase().contains(search.toLowerCase())).map((p) => OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: provider?.id == p.id ? AppColors.primary : AppColors.input),
                  backgroundColor: provider?.id == p.id ? AppColors.primarySoft : AppColors.card,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() { provider = p; product = null; verified = null; });
                  },
                child: Row(children: [
                  Container(width: 34, height: 34, decoration: BoxDecoration(color: _accentBg(p.accent), borderRadius: BorderRadius.circular(8)), alignment: Alignment.center, child: Text(p.shortName.substring(0, p.shortName.length >= 3 ? 3 : p.shortName.length).toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: _accentFg(p.accent)))),
                  const SizedBox(width: 8),
                  Expanded(child: Text(p.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.foreground), overflow: TextOverflow.ellipsis)),
                ]),
              )).toList(),
            ),
          ],
          if (step == _Stage.details) ...[
            // ── Saved beneficiaries quick-fill ────────────────────
            Builder(builder: (context) {
              final saved = accountStore.beneficiaries
                  .where((b) => b['kind'] == service.dbValue)
                  .toList();
              if (saved.isEmpty) return const SizedBox.shrink();
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Saved recipients', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: saved.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final b = saved[i];
                      return ActionChip(
                        avatar: const Icon(Icons.person_rounded, size: 16),
                        label: Text('${b['nickname']} · ${b['recipient']}', style: const TextStyle(fontSize: 12)),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            recipient.text = b['recipient']?.toString() ?? '';
                            verified = null;
                          });
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ]);
            }),
            if (service == ServiceKind.electricity) ...[
              Row(children: ['Prepaid', 'Postpaid'].map((t) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: OutlinedButton(
                style: OutlinedButton.styleFrom(backgroundColor: meterType == t ? AppColors.primary : null, foregroundColor: meterType == t ? Colors.white : AppColors.foreground, side: BorderSide(color: AppColors.input)),
                onPressed: () => setState(() { meterType = t; verified = null; }),
                child: Text(t),
              )))).toList()),
              const SizedBox(height: 16),
            ],
            Text(provider?.inputLabel ?? (service == ServiceKind.electricity ? 'Meter number' : service == ServiceKind.betting ? 'Customer ID' : 'Phone number'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: recipient,
              keyboardType: (isPhone || service == ServiceKind.electricity || service == ServiceKind.cable) ? TextInputType.number : TextInputType.text,
              onChanged: (_) => setState(() => verified = null),
              decoration: InputDecoration(hintText: provider?.inputPlaceholder ?? 'Enter details', filled: true, fillColor: AppColors.card, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 6),
            Text(recipient.text.isNotEmpty && !detailsValid ? 'Enter a valid ${provider?.inputLabel?.toLowerCase() ?? 'value'}.' : service == ServiceKind.education ? 'We only request what this product requires.' : 'Your details are encrypted during payment.', style: TextStyle(color: recipient.text.isNotEmpty && !detailsValid ? AppColors.destructive : AppColors.mutedForeground, fontSize: 12)),
            if (requiresVerification) ...[
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, height: 54, child: OutlinedButton(
                onPressed: (!detailsValid || verifying) ? null : verify,
                child: verifying
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : verified != null
                        ? const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.check_circle, color: AppColors.success), SizedBox(width: 8), Text('Verified')])
                        : const Text('Verify customer'),
              )),
            ],
            if (verified != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.successSoft, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.success.withValues(alpha: 0.3))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('CUSTOMER VERIFIED', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w800, fontSize: 11)),
                  const SizedBox(height: 6),
                  Text(verified!['name'].toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                  if (verified!['address'] != null) Text(verified!['address'].toString(), style: const TextStyle(color: AppColors.mutedForeground)),
                  Text('${provider?.shortName ?? ''} · ${service == ServiceKind.electricity ? '$meterType meter' : recipient.text}', style: const TextStyle(color: AppColors.mutedForeground, fontSize: 12)),
                ]),
              ),
            ],
            const SizedBox(height: 16),
            Row(children: [
              Checkbox(value: saveBeneficiary, onChanged: (v) => setState(() => saveBeneficiary = v ?? false)),
              const Text('Save for next time', style: TextStyle(fontWeight: FontWeight.w600)),
            ]),
          ],
          if (step == _Stage.product) ...[
            if (service == ServiceKind.data) ...[
              Wrap(spacing: 8, children: ['All', 'Daily', 'Weekly', 'Monthly'].map((c) => ChoiceChip(label: Text(c), selected: category == c, onSelected: (_) => setState(() => category = c))).toList()),
              const SizedBox(height: 12),
            ],
            ...displayProducts.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => setState(() => product = p),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: product?.id == p.id ? AppColors.primary : AppColors.border), borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [Text(p.name, style: displayStyleOf(context,size: 15)), if (p.badge != null) ...[const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: AppColors.highlightSoft, borderRadius: BorderRadius.circular(999)), child: Text(p.badge!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.highlightForeground)))]]),
                      const SizedBox(height: 4),
                      Text(p.subtitle, style: const TextStyle(color: AppColors.mutedForeground, fontSize: 12)),
                    ])),
                    Text(formatNaira(p.priceKobo).replaceAll('.00', ''), style: const TextStyle(fontWeight: FontWeight.w800)),
                    if (product?.id == p.id) const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.check_circle, color: AppColors.primary)),
                  ]),
                ),
              ),
            )),
          ],
          if (step == _Stage.amount) ...[
            const Text('Amount', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.input)),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(children: [
                const Text('₦', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                Expanded(child: TextField(
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(() => amount = v.replaceAll(RegExp(r'\D'), '')),
                  decoration: const InputDecoration(border: InputBorder.none, hintText: '0'),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                )),
              ]),
            ),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: (quickAmounts[service] ?? [500, 1000, 2000, 5000]).map((a) => OutlinedButton(
              style: OutlinedButton.styleFrom(backgroundColor: amount == '$a' ? AppColors.primary : null, foregroundColor: amount == '$a' ? Colors.white : AppColors.foreground),
              onPressed: () => setState(() => amount = '$a'),
              child: Text(formatNaira(a * 100).replaceAll('.00', '')),
            )).toList()),
          ],
          if (step == _Stage.review && provider != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Container(width: 40, height: 40, decoration: BoxDecoration(color: _accentBg(provider!.accent), borderRadius: BorderRadius.circular(10)), alignment: Alignment.center, child: Text(provider!.shortName.substring(0, 3).toUpperCase(), style: TextStyle(fontWeight: FontWeight.w900, color: _accentFg(provider!.accent), fontSize: 11))),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text("You're buying", style: TextStyle(color: AppColors.mutedForeground, fontSize: 12)),
                  Text(product?.name ?? service.shortTitle, style: displayStyleOf(context,size: 16)),
                ]),
              ]),
            ),
            const SizedBox(height: 16),
            _receiptRow('Provider', provider!.name),
            _receiptRow(provider?.inputLabel ?? 'Recipient', recipient.text),
            if (verified != null) _receiptRow('Customer', verified!['name'].toString()),
            if (service == ServiceKind.electricity) _receiptRow('Meter type', meterType),
            if (product != null) _receiptRow('Product', '${product!.name} · ${product!.subtitle}'),
            _receiptRow('Total charge', formatNaira(totalKobo), bold: true),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(border: Border.all(color: AppColors.primary), borderRadius: BorderRadius.circular(12), color: AppColors.primarySoft),
              child: const Row(children: [Icon(Icons.wallet_rounded, color: AppColors.primary), SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Pay with DataVault wallet', style: TextStyle(fontWeight: FontWeight.w800)), Text('Balance debits atomically via secure ledger.', style: TextStyle(color: AppColors.mutedForeground, fontSize: 12))])), Icon(Icons.check_circle, color: AppColors.primary)]),
            ),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, height: 54, child: FilledButton(onPressed: pay, child: Text('Pay ${formatNaira(totalKobo)}'))),
          ],
          if (step != _Stage.review) ...[
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, height: 54, child: FilledButton(
              onPressed: _canContinue() ? () => setState(() => stageIndex++) : null,
              child: const Text('Continue'),
            )),
          ],
        ]),
      ),
    );
  }

  bool _canContinue() {
    switch (stage) {
      case _Stage.provider:
        return provider != null;
      case _Stage.details:
        return detailsValid && (!requiresVerification || verified != null);
      case _Stage.product:
        return product != null;
      case _Stage.amount:
        return amountValid;
      default:
        return true;
    }
  }

  String _stepTitle() {
    switch (stage) {
      case _Stage.provider:
        return service == ServiceKind.electricity ? 'Choose your Disco' : service == ServiceKind.education ? 'Choose an examination' : 'Choose a provider';
      case _Stage.details:
        return service == ServiceKind.electricity ? 'Verify your meter' : service == ServiceKind.cable ? 'Verify your decoder' : service == ServiceKind.betting ? 'Verify your account' : 'Who is this for?';
      case _Stage.product:
        return service == ServiceKind.data ? 'Choose a data plan' : service == ServiceKind.cable ? 'Choose a package' : 'Choose a product';
      case _Stage.amount:
        return 'How much?';
      case _Stage.review:
        return 'Review and pay';
    }
  }

  String _stepDescription() {
    switch (stage) {
      case _Stage.provider:
        return 'Tap one option to continue.';
      case _Stage.details:
        return 'Enter only the details needed for this purchase.';
      case _Stage.product:
        return 'Compare options and select the right one.';
      case _Stage.amount:
        return 'Enter an amount or pick a quick option.';
      case _Stage.review:
        return 'Check every detail before you confirm payment.';
    }
  }

  Widget _receiptRow(String k, String v, {bool bold = false}) => Container(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: borderColorOf(context)))),
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k, style: TextStyle(color: mutedColorOf(context))),
          const SizedBox(width: 16),
          Flexible(child: Text(v, textAlign: TextAlign.right, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w700))),
        ]),
      );

  Color _accentBg(String accent) {
    switch (accent) {
      case 'yellow':
        return AppColors.highlight;
      case 'red':
        return const Color(0xFFF9E5E0);
      case 'green':
        return AppColors.successSoft;
      case 'teal':
        return AppColors.accent;
      case 'blue':
        return AppColors.primarySoft;
      case 'navy':
        return AppColors.brand;
      default:
        return const Color(0xFFF9EAD2);
    }
  }

  Color _accentFg(String accent) {
    switch (accent) {
      case 'yellow':
        return AppColors.highlightForeground;
      case 'red':
        return const Color(0xFFC0392B);
      case 'green':
        return AppColors.success;
      case 'teal':
        return AppColors.accentForeground;
      case 'blue':
        return AppColors.primary;
      case 'navy':
        return Colors.white;
      default:
        return const Color(0xFFC2761A);
    }
  }
}
