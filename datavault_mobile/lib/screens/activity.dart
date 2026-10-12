import 'package:flutter/material.dart';
import '../account_repository.dart';
import '../account_store.dart';
import '../app_logger.dart';
import '../theme.dart';
import '../widgets.dart';
import 'home.dart';
import 'transaction_detail.dart';

// Maps display filter labels → Supabase `kind` column values (null = All).
const _filterKinds = <String, String?>{
  'All': null,
  'Airtime': 'airtime',
  'Data': 'data',
  'Electricity': 'electricity',
  'Cable': 'cable',
  'Education': 'education',
  'Internet': 'internet',
  'Betting': 'betting',
  'Top-up': 'wallet_funding',
};

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  String _q = '';
  String _filter = 'All';

  // Paginated rows for the current filter.
  List<Map<String, dynamic>> _rows = [];
  bool _loadingMore = false;
  bool _hasMore = true; // false once a page returns fewer rows than pageSize

  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    if (accountStore.loading) accountStore.refresh();
    accountStore.addListener(_onStoreChange);
    _scroll.addListener(_onScroll);
    // Seed the local list from the already-loaded store data.
    _seedFromStore();
  }

  @override
  void dispose() {
    accountStore.removeListener(_onStoreChange);
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  // ── data helpers ────────────────────────────────────────────────────────────

  void _onStoreChange() {
    // When the store refreshes (e.g. after a purchase), reset to page 1.
    _seedFromStore();
    setState(() {});
  }

  /// Resets the paginated list to the store's first-page data for the active
  /// filter, so we don't have to make an extra network call after a refresh.
  void _seedFromStore() {
    final kind = _filterKinds[_filter];
    final all = accountStore.data.transactions;
    _rows = kind == null
        ? List.of(all)
        : all.where((t) => t['kind'] == kind).toList();
    // If the store returned a full page, there may be more on the server.
    _hasMore = accountStore.data.transactions.length >=
        AccountRepository.txPageSize;
  }

  void _onScroll() {
    if (_scroll.position.pixels >=
            _scroll.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _hasMore &&
        _q.isEmpty) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_rows.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final cursor = _rows.last['created_at']?.toString() ?? '';
      final kind = _filterKinds[_filter];
      final next = await AccountRepository.fetchMoreTransactions(
        beforeCreatedAt: cursor,
        kindFilter: kind,
      );
      setState(() {
        _rows.addAll(next);
        _hasMore = next.length >= AccountRepository.txPageSize;
        _loadingMore = false;
      });
    } catch (e, stack) {
      logError('ActivityScreen._loadMore failed', e, stack);
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _onRefresh() async {
    await accountStore.refresh();
    // _seedFromStore is called by _onStoreChange via the listener.
  }

  void _onFilterChanged(String f) {
    if (_filter == f) return;
    setState(() {
      _filter = f;
      _q = '';
      _seedFromStore();
    });
  }

  // ── filtered view ───────────────────────────────────────────────────────────

  /// Rows currently shown — either the full paginated list (no search)
  /// or a client-side substring search over the already-loaded rows.
  List<Map<String, dynamic>> get _visibleRows {
    if (_q.isEmpty) return _rows;
    final lower = _q.toLowerCase();
    return _rows.where((t) {
      return ('${t['title']}${t['recipient']}${t['reference']}')
          .toLowerCase()
          .contains(lower);
    }).toList();
  }

  // ── build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final visible = _visibleRows;

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView(
        controller: _scroll,
        padding: const EdgeInsets.all(20),
        children: [
          // Search field
          TextField(
            onChanged: (v) => setState(() => _q = v),
            decoration: InputDecoration(
              hintText: 'Search by service, recipient or reference',
              prefixIcon:
                  const Icon(Icons.search, color: AppColors.mutedForeground),
              filled: true,
              fillColor: AppColors.card,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border)),
            ),
          ),
          const SizedBox(height: 14),

          // Filter chips
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _filterKinds.keys.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final f = _filterKinds.keys.elementAt(i);
                final selected = _filter == f;
                return FilterChip(
                  label: Text(f,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? Colors.white
                              : AppColors.mutedForeground,
                          fontSize: 12)),
                  selected: selected,
                  onSelected: (_) => _onFilterChanged(f),
                  backgroundColor: AppColors.card,
                  selectedColor: AppColors.primary,
                  checkmarkColor: Colors.white,
                  side: BorderSide(
                      color: selected ? AppColors.primary : AppColors.border),
                  showCheckmark: false,
                );
              },
            ),
          ),
          const SizedBox(height: 14),

          // Transaction list
          Container(
            decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border)),
            child: accountStore.loading
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()))
                : visible.isEmpty
                    ? StateView(
                        icon: Icons.receipt_long_outlined,
                        title: _q.isEmpty && _filter == 'All'
                            ? 'No payments yet'
                            : 'No matching payments',
                        description: _q.isEmpty && _filter == 'All'
                            ? 'Completed payments and receipts will appear here.'
                            : 'Try a different search or filter.',
                      )
                    : Column(
                        children: visible.asMap().entries.map((e) {
                          final t = e.value;
                          final isFirst = e.key == 0;
                          final isLast = e.key == visible.length - 1;
                          return InkWell(
                            onTap: () => pushTransactionDetail(context, t),
                            borderRadius: BorderRadius.only(
                              topLeft: isFirst
                                  ? const Radius.circular(14)
                                  : Radius.zero,
                              topRight: isFirst
                                  ? const Radius.circular(14)
                                  : Radius.zero,
                              bottomLeft: isLast
                                  ? const Radius.circular(14)
                                  : Radius.zero,
                              bottomRight: isLast
                                  ? const Radius.circular(14)
                                  : Radius.zero,
                            ),
                            child: TransactionRow(t: t),
                          );
                        }).toList(),
                      ),
          ),

          // Load-more indicator / end-of-list message
          if (_q.isEmpty) ...[
            const SizedBox(height: 16),
            if (_loadingMore)
              const Center(child: CircularProgressIndicator(strokeWidth: 2))
            else if (!_hasMore && _rows.isNotEmpty)
              Center(
                child: Text(
                  'All ${_rows.length} transactions loaded',
                  style: const TextStyle(
                      color: AppColors.mutedForeground, fontSize: 12),
                ),
              )
            else if (_hasMore && _rows.isNotEmpty)
              Center(
                child: TextButton(
                  onPressed: _loadMore,
                  child: const Text('Load more',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
