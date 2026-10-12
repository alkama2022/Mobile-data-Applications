import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'account_repository.dart';
import 'app_logger.dart';
import 'cache_service.dart';

class AccountStore extends ChangeNotifier {
  AccountData data = AccountData();
  bool loading = true;
  bool error = false;
  String? errorMessage;
  bool _refreshing = false;

  /// Primes the store from the on-disk cache instantly, then fires a network
  /// refresh. This makes the home screen render with stale data in < 1 ms
  /// while the real data loads in the background.
  Future<void> loadCacheThenRefresh() async {
    final cached = await CacheService.loadAccount();
    if (cached != null) {
      data = AccountData(
        profile: cached.profile,
        wallet: cached.wallet,
        transactions: cached.transactions,
        notifications: cached.notifications,
        beneficiaries: cached.beneficiaries,
      );
      loading = false; // show stale data immediately
      notifyListeners();
    }
    await refresh(); // then update with live data
  }

  /// Full network refresh with exponential-backoff retry (up to 3 attempts).
  Future<void> refresh({int _attempt = 0}) async {
    if (_refreshing) return;
    _refreshing = true;
    final isFirstLoad = data.transactions.isEmpty && data.profile == null;
    if (isFirstLoad) loading = true;
    error = false;
    errorMessage = null;
    notifyListeners();
    try {
      data = await AccountRepository.fetch();
      // Persist to disk cache so next cold launch is instant.
      await CacheService.saveAccount(
        wallet: data.wallet,
        profile: data.profile,
        transactions: data.transactions,
        notifications: data.notifications,
        beneficiaries: data.beneficiaries,
      );
    } catch (e, stack) {
      logError('AccountStore.refresh failed (attempt ${_attempt + 1})', e, stack);

      // Exponential backoff: retry up to 2 more times (1 s, 2 s) before giving up.
      if (_attempt < 2) {
        _refreshing = false;
        await Future.delayed(Duration(seconds: 1 << _attempt)); // 1s, 2s
        await refresh(_attempt: _attempt + 1);
        return;
      }

      error = true;
      errorMessage = friendlyError(e);
    }
    loading = false;
    _refreshing = false;
    notifyListeners();
  }

  /// Lightweight targeted refresh — only re-fetches wallet + latest
  /// transactions. Called after a purchase so we don't reload the full
  /// account (profile, beneficiaries, notifications) unnecessarily.
  Future<void> refreshWalletAndTransactions() async {
    if (_refreshing) return;
    final user = AccountRepository.currentUserId;
    if (user == null) return;
    try {
      final results = await Future.wait([
        AccountRepository.fetchWallet(user),
        AccountRepository.fetchRecentTransactions(user),
      ]);
      data = AccountData(
        profile: data.profile,
        wallet: results[0] as Map<String, dynamic>?,
        transactions: (results[1] as List).cast<Map<String, dynamic>>(),
        notifications: data.notifications,
        beneficiaries: data.beneficiaries,
      );
      notifyListeners();
      // Update the wallet + tx portion of the cache.
      await CacheService.saveAccount(
        wallet: data.wallet,
        profile: data.profile,
        transactions: data.transactions,
        notifications: data.notifications,
        beneficiaries: data.beneficiaries,
      );
    } catch (e, stack) {
      logError('refreshWalletAndTransactions failed', e, stack);
    }
  }

  /// Clears cached data — call on logout.
  Future<void> clearOnLogout() async {
    await CacheService.clear();
    data = AccountData();
    loading = true;
    error = false;
    errorMessage = null;
    _refreshing = false;
    notifyListeners();
  }

  /// Test hook.
  @visibleForTesting
  void resetForTests() {
    data = AccountData();
    loading = true;
    error = false;
    errorMessage = null;
    _refreshing = false;
  }

  int get unread =>
      data.notifications.where((n) => n['read_at'] == null).length;

  List<Map<String, dynamic>> get beneficiaries => data.beneficiaries;

  int get walletBalance => data.wallet?['balance_kobo'] as int? ?? 0;
}

final AccountStore accountStore = AccountStore();
