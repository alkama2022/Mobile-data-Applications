import 'package:flutter/material.dart';
import '../account_store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'home.dart';
import 'transaction_detail.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  String q = '';
  String _filter = 'All';

  static const _filters = ['All', 'Airtime', 'Data', 'Electricity', 'Cable', 'Education', 'Internet', 'Betting', 'Top-up'];

  @override
  void initState() {
    super.initState();
    if (accountStore.loading) accountStore.refresh();
    accountStore.addListener(_onChange);
  }

  void _onChange() => setState(() {});

  @override
  void dispose() {
    accountStore.removeListener(_onChange);
    super.dispose();
  }

  bool _matchesFilter(Map<String, dynamic> t) {
    if (_filter == 'All') return true;
    final kind = t['kind']?.toString() ?? '';
    final map = {
      'Airtime': 'airtime',
      'Data': 'data',
      'Electricity': 'electricity',
      'Cable': 'cable',
      'Education': 'education',
      'Internet': 'internet',
      'Betting': 'betting',
      'Top-up': 'wallet_funding',
    };
    return kind == (map[_filter] ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final rows = accountStore.data.transactions
        .where((t) => _matchesFilter(t))
        .where((t) => ('${t['title']}${t['recipient']}${t['reference']}').toLowerCase().contains(q.toLowerCase()))
        .toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          onChanged: (v) => setState(() => q = v),
          decoration: InputDecoration(
            hintText: 'Search by service, recipient or reference',
            prefixIcon: const Icon(Icons.search, color: AppColors.mutedForeground),
            filled: true,
            fillColor: AppColors.card,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
          ),
        ),
        const SizedBox(height: 14),
        // Filter chips
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _filters.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final f = _filters[i];
              final selected = _filter == f;
              return FilterChip(
                label: Text(f, style: TextStyle(fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.mutedForeground, fontSize: 12)),
                selected: selected,
                onSelected: (_) => setState(() => _filter = f),
                backgroundColor: AppColors.card,
                selectedColor: AppColors.primary,
                checkmarkColor: Colors.white,
                side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
                showCheckmark: false,
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
          child: accountStore.loading
              ? const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
              : rows.isEmpty
                  ? StateView(
                      icon: Icons.receipt_long_outlined,
                      title: q.isEmpty && _filter == 'All' ? 'No payments yet' : 'No matching payments',
                      description: q.isEmpty && _filter == 'All'
                          ? 'Completed payments and receipts will appear here.'
                          : 'Try a different search or filter.',
                    )
                  : Column(
                      children: rows.asMap().entries.map((e) {
                        final t = e.value;
                        return InkWell(
                          onTap: () => pushTransactionDetail(context, t),
                          borderRadius: BorderRadius.only(
                            topLeft: e.key == 0 ? const Radius.circular(14) : Radius.zero,
                            topRight: e.key == 0 ? const Radius.circular(14) : Radius.zero,
                            bottomLeft: e.key == rows.length - 1 ? const Radius.circular(14) : Radius.zero,
                            bottomRight: e.key == rows.length - 1 ? const Radius.circular(14) : Radius.zero,
                          ),
                          child: TransactionRow(t: t),
                        );
                      }).toList(),
                    ),
        ),
      ],
    );
  }
}
