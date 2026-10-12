import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Lightweight wrapper around connectivity_plus.
/// Exposes a stream and a synchronous `isOnline` getter used by the UI.
class ConnectivityService extends ChangeNotifier {
  ConnectivityService() {
    Connectivity().onConnectivityChanged.listen(_onChanged);
    // Bootstrap initial state.
    Connectivity().checkConnectivity().then(_onChanged);
  }

  bool _online = true;

  bool get isOnline => _online;

  void _onChanged(List<ConnectivityResult> results) {
    final wasOnline = _online;
    _online = results.any((r) =>
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.ethernet);
    if (_online != wasOnline) notifyListeners();
  }
}

final connectivityService = ConnectivityService();
