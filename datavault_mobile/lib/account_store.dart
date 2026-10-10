import 'package:flutter/material.dart';
import 'account_repository.dart';

class AccountStore extends ChangeNotifier {
  AccountData data = AccountData();
  bool loading = true;
  bool error = false;
  String? errorMessage;

  Future<void> refresh() async {
    loading = true;
    error = false;
    errorMessage = null;
    notifyListeners();
    try {
      data = await AccountRepository.fetch();
    } catch (e) {
      error = true;
      errorMessage = e.toString();
    }
    loading = false;
    notifyListeners();
  }

  int get unread => data.notifications.where((n) => n['read_at'] == null).length;

  List<Map<String, dynamic>> get beneficiaries => data.beneficiaries;

  int get walletBalance => data.wallet?['balance_kobo'] as int? ?? 0;
}

final AccountStore accountStore = AccountStore();
