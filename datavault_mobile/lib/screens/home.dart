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
    // Refresh data a couple of seconds after mount so the wallet card
    // reflects any schedules the server cron may have just executed.
    // The actual payment logic lives in supabase/functions/schedule-cron
    // and is triggered by pg_cron — not by the client.
    Future.delayed(const Duration(seconds: 3), () async {
      if (mounted) await accountStore.refresh();
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

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040),
        child: RefreshIndicator(
          onRefresh: accountStore.refresh,
          child: ListView(
            padding: const EdgeInsets.all(20),
        children: [
          Text('Hello, $name', style: displayStyleOf(context, size: 24)),
          const SizedBox(height: 4),
          Text('A secure home for airtime, data and bill payments.',
              style: TextStyle(color: mutedColorOf(context))),
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
                        const Text(
                          'AVAILABLE BALANCE',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: visible ? 'Hide balance' : 'Show balance',
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            setState(() => visible = !visible);
                          },
                          icon: Icon(
                            visible ? Icons.visibility_off : Icons.visibility,
                            color: Colors.white70,
                            size: 20,
                          ),
                          visualDensity: VisualDensity.compact,
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
                    child: FilledButton.icon(
                      onPressed: () => context.push('/app/topup'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.highlight,
                        foregroundColor: AppColors.highlightForeground,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text(
                        'Add money',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Pay button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.go('/app/services'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.send_rounded),
                      label: const Text(
                        'Pay a bill',
                        style: TextStyle(fontWeight: FontWeight.w800),
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
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 680 ? 4 : 3;
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: constraints.maxWidth >= 680 ? 1.5 : 1.0,
                children: ServiceKind.values.toList().asMap().entries.map((e) {
                  final idx = e.key;
                  final service = e.value;
                  return Semantics(
                    button: true,
                    label: service.title,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        context.push('/app/services/${service.dbValue}');
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: cardColorOf(context),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderColorOf(context)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: service.iconBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                service.icon,
                                color: service.iconFg,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                service.shortTitle,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                      .animate(delay: Duration(milliseconds: 60 * idx))
                      .fadeIn(duration: 300.ms)
                      .scale(
                        begin: const Offset(0.95, 0.95),
                        curve: Curves.easeOut,
                      );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 20),

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

          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            leading: const Icon(Icons.more_horiz_rounded),
            title: Text(
              'More options',
              style: displayStyleOf(context, size: 18),
            ),
            subtitle: Text(
              'Schedules, gifts, bulk payments and storefront',
              style: TextStyle(color: mutedColorOf(context)),
            ),
            children: [
              _HomeOption(
                icon: Icons.schedule_rounded,
                title: 'Auto-buy & schedules',
                description: 'Set up recurring payments',
                onTap: () => context.push('/app/schedules'),
              ),
              _HomeOption(
                icon: Icons.card_giftcard_rounded,
                title: 'Gift & request',
                description: 'Share data with someone',
                onTap: () => context.push('/app/gift'),
              ),
              _HomeOption(
                icon: Icons.groups_rounded,
                title: 'Bulk dispatch',
                description: 'Pay multiple numbers at once',
                onTap: () => context.push('/app/bulk'),
              ),
              _HomeOption(
                icon: Icons.storefront_rounded,
                title: 'My storefront',
                description: 'Sell with your own link',
                onTap: () => context.push('/app/storefront'),
              ),
            ],
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
      ),
    );
  }
}

class _HomeOption extends StatelessWidget {
  const _HomeOption({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Text(description),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
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
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: borderColorOf(context)))),
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: funding ? AppColors.successSoft : Theme.of(context).brightness == Brightness.dark ? AppColors.darkMuted : AppColors.muted,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Icon(
            funding ? Icons.south_west_rounded : Icons.north_east_rounded,
            color: funding ? AppColors.success : mutedColorOf(context),
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13), overflow: TextOverflow.ellipsis),
          Text(
            '${t['recipient']} · ${formatDate(t['created_at']?.toString() ?? '')}',
            style: TextStyle(color: mutedColorOf(context), fontSize: 11),
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
        Icon(Icons.chevron_right, size: 16, color: mutedColorOf(context)),
      ]),
    );
  }
}
