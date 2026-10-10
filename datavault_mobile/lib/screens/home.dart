import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../account_store.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import '../repeat_helper.dart';
import '../services/schedule_service.dart';
import 'transaction_detail.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool visible = true;

  @override
  void initState() {
    super.initState();
    if (accountStore.loading) accountStore.refresh();
    accountStore.addListener(_onChange);
    // Fire-and-forget: run due auto-buys, then refresh balance
    Future.microtask(() async {
      try {
        final ran = await ScheduleService.runDue();
        if (ran > 0) await accountStore.refresh();
      } catch (_) {}
    });
  }

  void _onChange() => setState(() {});

  @override
  void dispose() {
    accountStore.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = (accountStore.data.profile?['full_name'] as String? ?? 'there').split(' ').first;
    final balance = accountStore.data.wallet?['balance_kobo'] as int? ?? 0;
    final txs = accountStore.data.transactions;

    return RefreshIndicator(
      onRefresh: accountStore.refresh,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Hello, $name 👋', style: displayStyleOf(context, size: 24)),
          const SizedBox(height: 4),
          const Text('A secure home for airtime, data and bill payments.', style: TextStyle(color: AppColors.mutedForeground)),
          const SizedBox(height: 20),

          // ── Wallet card ───────────────────────────────────────────
          if (accountStore.loading)
            const HomeSkeletonLoader()
          else if (accountStore.error)
            StateView(icon: Icons.error_outline, title: 'Something went wrong', description: 'Pull to refresh and try again.')
          else
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(colors: [AppColors.brand, AppColors.brandElevated]),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Text('AVAILABLE BALANCE', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => visible = !visible);
                          },
                          child: Icon(visible ? Icons.visibility_off : Icons.visibility, color: Colors.white70, size: 18),
                        ),
                      ]),
                      const SizedBox(height: 6),
                      Text(
                        visible ? formatNaira(balance) : '₦ ••••••',
                        style: displayStyle(size: 34, color: Colors.white),
                      ),
                    ]),
                  ),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  // Top-up button
                  Expanded(
                    child: GestureDetector(
                      onTap: () => context.push('/app/topup'),
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(color: AppColors.highlight, borderRadius: BorderRadius.circular(10)),
                        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.add_rounded, color: AppColors.highlightForeground, size: 18),
                          SizedBox(width: 6),
                          Text('Add money', style: TextStyle(color: AppColors.highlightForeground, fontWeight: FontWeight.w800, fontSize: 13)),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Pay button
                  Expanded(
                    child: GestureDetector(
                      onTap: () => context.go('/app/services'),
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.send_rounded, color: Colors.white, size: 18),
                          SizedBox(width: 6),
                          Text('Pay', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                        ]),
                      ),
                    ),
                  ),
                ]),
              ]),
            ),

          const SizedBox(height: 28),

          // ── Quick services ────────────────────────────────────────
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _Eyebrow('Quick access'),
              const SizedBox(height: 4),
              Text('What do you need?', style: displayStyleOf(context, size: 20)),
            ])),
            TextButton(onPressed: () => context.go('/app/services'), child: const Text('View all', style: TextStyle(fontWeight: FontWeight.w800))),
          ]),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.85,
            children: ServiceKind.values.toList().asMap().entries.map((e) {
              final idx = e.key;
              final s = e.value;
              return InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  context.push('/app/services/${s.dbValue}');
                },
                borderRadius: BorderRadius.circular(14),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(color: s.iconBg, borderRadius: BorderRadius.circular(14)),
                    child: Icon(s.icon, color: s.iconFg, size: 24),
                  ),
                  const SizedBox(height: 6),
                  Text(s.shortTitle, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ).animate(delay: Duration(milliseconds: 60 * idx))
               .fadeIn(duration: 300.ms)
               .scale(begin: const Offset(0.85, 0.85), curve: Curves.easeOut);
            }).toList(),
          ),

          const SizedBox(height: 28),

          // ── Buy again (1-tap repeat) ──────────────────────────────
          Builder(builder: (_) {
            final again = txs.where((t) => t['kind'] != 'wallet_funding' && (t['status']?.toString() ?? 'success') == 'success').take(5).toList();
            if (again.isEmpty) return const SizedBox.shrink();
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Buy again', style: displayStyleOf(context, size: 18)),
              const SizedBox(height: 10),
              SizedBox(
                height: 124,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: again.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (_, i) {
                    final t = again[i];
                    return Container(
                      width: 188,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: cardColorOf(context), borderRadius: BorderRadius.circular(14), border: Border.all(color: borderColorOf(context))),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t['title']?.toString() ?? '', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Theme.of(context).colorScheme.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text('${t['recipient']}', style: TextStyle(color: mutedColorOf(context), fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const Spacer(),
                        SizedBox(
                          height: 44,
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => repeatTransaction(context, t),
                            child: Text('Repeat ${formatNaira(t['amount_kobo'] as int? ?? 0).replaceAll('.00', '')}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ]),
                    );
                  },
                ),
              ),
              const SizedBox(height: 28),
            ]);
          }),

          // ── Schedules entry ─────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColorOf(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColorOf(context)),
            ),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.schedule_rounded, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Auto-buy & schedules', style: TextStyle(fontWeight: FontWeight.w800)),
                Text('Never run out of data', style: TextStyle(color: AppColors.mutedForeground, fontSize: 12)),
              ])),
              TextButton(onPressed: () => context.push('/app/schedules'), child: const Text('Manage')),
            ]),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: AppColors.successSoft, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.card_giftcard_rounded, color: AppColors.success),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Gift & Request', style: TextStyle(fontWeight: FontWeight.w800)),
                Text('Share data via WhatsApp', style: TextStyle(color: AppColors.mutedForeground, fontSize: 12)),
              ])),
              TextButton(onPressed: () => context.push('/app/gift'), child: const Text('Open')),
            ]),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: AppColors.highlightSoft, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.groups_rounded, color: AppColors.highlightForeground),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Bulk dispatch', style: TextStyle(fontWeight: FontWeight.w800)),
                Text('Pay 100 numbers at once', style: TextStyle(color: AppColors.mutedForeground, fontSize: 12)),
              ])),
              TextButton(onPressed: () => context.push('/app/bulk'), child: const Text('Open')),
            ]),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: AppColors.brand, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.storefront_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('My storefront', style: TextStyle(fontWeight: FontWeight.w800)),
                Text('Sell with your own link', style: TextStyle(color: AppColors.mutedForeground, fontSize: 12)),
              ])),
              TextButton(onPressed: () => context.push('/app/storefront'), child: const Text('Open')),
            ]),
          ),
          const SizedBox(height: 28),

          // ── Recent activity ───────────────────────────────────────
          Row(children: [
            Expanded(child: Text('Recent activity', style: displayStyleOf(context, size: 18))),
            TextButton(onPressed: () => context.go('/app/activity'), child: const Text('See all', style: TextStyle(fontWeight: FontWeight.w800))),
          ]),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(color: cardColorOf(context), borderRadius: BorderRadius.circular(14), border: Border.all(color: borderColorOf(context))),
            child: txs.isEmpty
                ? const StateView(icon: Icons.receipt_long_outlined, title: 'No payments yet', description: 'Your completed payments will appear here.')
                : Column(
                    children: txs.take(5).toList().asMap().entries.map((e) {
                      final t = e.value;
                      return InkWell(
                        onTap: () => pushTransactionDetail(context, t),
                        borderRadius: BorderRadius.only(
                          topLeft: e.key == 0 ? const Radius.circular(14) : Radius.zero,
                          topRight: e.key == 0 ? const Radius.circular(14) : Radius.zero,
                          bottomLeft: e.key == (txs.take(5).length - 1) ? const Radius.circular(14) : Radius.zero,
                          bottomRight: e.key == (txs.take(5).length - 1) ? const Radius.circular(14) : Radius.zero,
                        ),
                        child: TransactionRow(t: t),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  final String text;
  const _Eyebrow(this.text);

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2, color: AppColors.primary));
}

class TransactionRow extends StatelessWidget {
  final Map<String, dynamic> t;
  const TransactionRow({super.key, required this.t});

  @override
  Widget build(BuildContext context) {
    final funding = t['kind'] == 'wallet_funding';
    final int amount = t['amount_kobo'] as int? ?? 0;
    final String status = (t['status']?.toString() ?? 'success').toLowerCase();
    final Color statusColor = status == 'failed' ? AppColors.destructive : AppColors.success;

    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: funding ? AppColors.successSoft : AppColors.muted,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Icon(
            funding ? Icons.south_west_rounded : Icons.north_east_rounded,
            color: funding ? AppColors.success : AppColors.mutedForeground,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13), overflow: TextOverflow.ellipsis),
          Text(
            '${t['recipient']} · ${formatDate(t['created_at']?.toString() ?? '')}',
            style: const TextStyle(color: AppColors.mutedForeground, fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(
            '${funding ? '+' : '−'}${formatNaira(amount)}',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: funding ? AppColors.success : null),
          ),
          Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(width: 4),
        const Icon(Icons.chevron_right, size: 16, color: AppColors.mutedForeground),
      ]),
    );
  }
}
