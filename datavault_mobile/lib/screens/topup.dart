import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../account_store.dart';
import '../config.dart';
import '../format.dart';
import '../services/paystack_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';
import '../widgets.dart';

enum _TopUpStep { amount, review, processing, success }

class TopUpScreen extends StatefulWidget {
  const TopUpScreen({super.key});

  @override
  State<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends State<TopUpScreen> {
  _TopUpStep step = _TopUpStep.amount;
  final amountCtrl = TextEditingController();
  String rawAmount = '';
  String selectedMethod = 'card';

  static const quickAmounts = [1000, 2000, 5000, 10000, 20000, 50000];

  static const methods = [
    (id: 'card', label: 'Debit / Credit Card', icon: Icons.credit_card_rounded, sub: 'Visa, Mastercard, Verve'),
    (id: 'transfer', label: 'Bank Transfer', icon: Icons.account_balance_rounded, sub: 'Instant settlement'),
    (id: 'ussd', label: 'USSD', icon: Icons.dialpad_rounded, sub: '*737#, *901# and more'),
  ];

  int get amountKobo => (int.tryParse(rawAmount) ?? 0) * 100;
  bool get amountValid => amountKobo >= 10000; // min ₦100

  Future<void> fund() async {
    setState(() => step = _TopUpStep.processing);
    final user = AppConfig.client.auth.currentUser;
    if (user == null) { _toast('Please sign in again.'); setState(() => step = _TopUpStep.review); return; }
    try {
      if (AppConfig.useEdge) {
        // Live Paystack: init checkout, open browser, credit happens via webhook.
        final ref = generateReference();
        final email = user.email ?? 'customer@datavault.ng';
        final init = await PaystackService.init(email: email, amountKobo: amountKobo, reference: ref);
        final url = Uri.tryParse(init['authorization_url']?.toString() ?? '');
        if (url != null) await launchUrl(url, mode: LaunchMode.externalApplication);
        _toast('Complete payment in browser — wallet credits automatically. Ref $ref');
        setState(() => step = _TopUpStep.review);
        return;
      }
      await Future.delayed(const Duration(milliseconds: 1800));
      // Demo fallback: debug only. Release requires Paystack Edge + webhook.
      if (kReleaseMode) throw Exception('Live top-up not configured. Deploy paystack-init/webhook and rebuild with --dart-define=USE_EDGE=true.');
      final ref = generateReference();
      await AppConfig.client.from('transactions').insert({
        'user_id': user.id,
        'kind': 'wallet_funding',
        'title': 'Wallet Top-up',
        'recipient': 'DataVault Wallet',
        'amount_kobo': amountKobo,
        'reference': ref,
        'provider': _methodLabel(),
        'status': 'success',
        'metadata': {'method': selectedMethod, 'channel': _methodLabel()},
      });
      // Update wallet balance
      final wallet = await AppConfig.client
          .from('wallets')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();
      if (wallet == null) {
        await AppConfig.client.from('wallets').insert({
          'user_id': user.id,
          'balance_kobo': amountKobo,
        });
      } else {
        final current = wallet['balance_kobo'] as int? ?? 0;
        await AppConfig.client
            .from('wallets')
            .update({'balance_kobo': current + amountKobo})
            .eq('user_id', user.id);
      }
      await accountStore.refresh();
      setState(() => step = _TopUpStep.success);
    } catch (e) {
      _toast('Top-up failed: ${e.toString().replaceFirst('Exception: ', '')}');
      setState(() => step = _TopUpStep.review);
    }
  }

  String _methodLabel() {
    return methods.firstWhere((m) => m.id == selectedMethod, orElse: () => methods.first).label;
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add money')),
      body: () {
        switch (step) {
          case _TopUpStep.processing:
            return _buildProcessing();
          case _TopUpStep.success:
            return _buildSuccess();
          case _TopUpStep.review:
            return _buildReview();
          case _TopUpStep.amount:
            return _buildAmount();
        }
      }(),
    );
  }

  Widget _buildAmount() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Eyebrow('Step 1 of 2'),
        const SizedBox(height: 10),
        Text('How much do you want to add?', style: displayStyleOf(context,size: 22)),
        const SizedBox(height: 6),
        const Text('Minimum top-up is ₦100.', style: TextStyle(color: AppColors.mutedForeground)),
        const SizedBox(height: 24),
        // Amount input
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: amountKobo > 0 && !amountValid ? AppColors.destructive : AppColors.input),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          child: Row(children: [
            const Text('₦', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                decoration: const InputDecoration(border: InputBorder.none, hintText: '0', filled: false),
                onChanged: (v) => setState(() => rawAmount = v.replaceAll(RegExp(r'\D'), '')),
              ),
            ),
          ]),
        ),
        if (rawAmount.isNotEmpty && !amountValid)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('Minimum top-up is ₦100', style: TextStyle(color: AppColors.destructive, fontSize: 12)),
          ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: quickAmounts.map((a) => OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: rawAmount == '$a' ? AppColors.primary : null,
              foregroundColor: rawAmount == '$a' ? Colors.white : AppColors.foreground,
              side: BorderSide(color: rawAmount == '$a' ? AppColors.primary : AppColors.border),
            ),
            onPressed: () {
              setState(() => rawAmount = '$a');
              amountCtrl.text = '$a';
            },
            child: Text(formatNaira(a * 100).replaceAll('.00', '')),
          )).toList(),
        ),
        const SizedBox(height: 32),
        Text('Payment method', style: displayStyleOf(context,size: 18)),
        const SizedBox(height: 12),
        ...methods.map((m) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: () => setState(() => selectedMethod = m.id),
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selectedMethod == m.id ? AppColors.primary : AppColors.border,
                  width: selectedMethod == m.id ? 2 : 1,
                ),
              ),
              child: Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: selectedMethod == m.id ? AppColors.primarySoft : AppColors.muted,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(m.icon, color: selectedMethod == m.id ? AppColors.primary : AppColors.mutedForeground),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(m.label, style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(m.sub, style: const TextStyle(color: AppColors.mutedForeground, fontSize: 12)),
                ])),
                if (selectedMethod == m.id)
                  const Icon(Icons.check_circle, color: AppColors.primary),
              ]),
            ),
          ),
        )),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity, height: 54,
          child: FilledButton(
            onPressed: amountValid ? () => setState(() => step = _TopUpStep.review) : null,
            child: Text('Continue${amountValid ? ' · ${formatNaira(amountKobo)}' : ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
      ]),
    );
  }

  Widget _buildReview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Eyebrow('Step 2 of 2'),
        const SizedBox(height: 10),
        Text('Review your top-up', style: displayStyleOf(context,size: 22)),
        const SizedBox(height: 6),
        const Text('Confirm the details below before proceeding.', style: TextStyle(color: AppColors.mutedForeground)),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(color: AppColors.successSoft, borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.success, size: 28),
              ),
            ]),
            const SizedBox(height: 16),
            Text(formatNaira(amountKobo), style: displayStyleOf(context,size: 36)),
            const SizedBox(height: 4),
            const Text('to DataVault wallet', style: TextStyle(color: AppColors.mutedForeground)),
          ]),
        ),
        const SizedBox(height: 20),
        _row('Amount', formatNaira(amountKobo)),
        _row('Payment method', _methodLabel()),
        _row('Destination', 'DataVault Wallet'),
        _row('Processing fee', 'Free'),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(12)),
          child: const Row(children: [
            Icon(Icons.lock_rounded, color: AppColors.primary, size: 18),
            SizedBox(width: 10),
            Expanded(child: Text('This top-up is encrypted and secured by DataVault.', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600))),
          ]),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity, height: 54,
          child: FilledButton(
            onPressed: fund,
            child: Text('Fund wallet · ${formatNaira(amountKobo)}', style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity, height: 48,
          child: TextButton(
            onPressed: () => setState(() => step = _TopUpStep.amount),
            child: const Text('Back', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }

  Widget _buildProcessing() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 88, height: 88,
            decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(999)),
            child: const Center(child: SizedBox(width: 40, height: 40, child: CircularProgressIndicator())),
          ),
          const SizedBox(height: 24),
          Text('Processing top-up', style: displayStyleOf(context,size: 22)),
          const SizedBox(height: 8),
          const Text('Please wait while we fund your wallet.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.mutedForeground)),
          const SizedBox(height: 28),
          const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.verified_user_rounded, color: AppColors.success, size: 16),
            SizedBox(width: 6),
            Text('Secured by DataVault', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w800, fontSize: 12)),
          ]),
        ]),
      ),
    );
  }

  Widget _buildSuccess() {
    final newBalance = accountStore.data.wallet?['balance_kobo'] as int? ?? 0;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const SizedBox(height: 20),
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(999), boxShadow: [BoxShadow(color: AppColors.successSoft, spreadRadius: 10, blurRadius: 0)]),
          child: const Icon(Icons.check, color: Colors.white, size: 36),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(color: AppColors.successSoft, borderRadius: BorderRadius.circular(999)),
          child: const Text('TOP-UP SUCCESSFUL', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w800, fontSize: 11)),
        ),
        const SizedBox(height: 12),
        Text('Wallet funded!', style: displayStyleOf(context,size: 26)),
        const SizedBox(height: 8),
        Text('${formatNaira(amountKobo)} has been added to your wallet.', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.mutedForeground)),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.brand, AppColors.brandElevated]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(children: [
            const Text('NEW BALANCE', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
            const SizedBox(height: 6),
            Text(formatNaira(newBalance), style: displayStyleOf(context,size: 32, color: Colors.white)),
          ]),
        ),
        const SizedBox(height: 24),
        _row('Amount added', formatNaira(amountKobo)),
        _row('Method', _methodLabel()),
        _row('Status', 'Successful'),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity, height: 54,
          child: FilledButton(
            onPressed: () => context.go('/app'),
            child: const Text('Back to home'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity, height: 48,
          child: TextButton(
            onPressed: () => context.go('/app/activity'),
            child: const Text('View transaction history'),
          ),
        ),
      ]),
    );
  }

  Widget _row(String k, String v) => Container(
    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(k, style: const TextStyle(color: AppColors.mutedForeground)),
      Text(v, style: const TextStyle(fontWeight: FontWeight.w800)),
    ]),
  );
}
