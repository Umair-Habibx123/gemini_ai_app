import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Verifies *real* internet reachability — not just that a network interface
/// exists — by probing a lightweight endpoint that returns HTTP 204.
///
/// Mirrors the `react-connection-guard` approach: a tiny, fast, no-content
/// probe (`generate_204`) is the most reliable signal of true connectivity,
/// because a device can be on Wi-Fi yet have no actual internet access.
class ConnectivityService with ChangeNotifier {
  // Google's zero-content endpoint — responds 204 with an empty body, so the
  // round trip is as cheap as possible.
  static const _probeUrl = 'https://www.gstatic.com/generate_204';
  static const _probeInterval = Duration(seconds: 15);
  static const _probeTimeout = Duration(seconds: 5);

  bool _hasInternet = true;
  bool _isChecking = false;

  bool get hasInternet => _hasInternet;
  bool get isChecking => _isChecking;

  Timer? _timer;
  StreamSubscription? _subscription;

  ConnectivityService() {
    _init();
  }

  Future<void> _init() async {
    await _probe();
    // Re-check immediately whenever the OS reports a network change…
    _subscription = Connectivity().onConnectivityChanged.listen((_) => _probe());
    // …and poll periodically to catch "connected but no internet" cases.
    _timer = Timer.periodic(_probeInterval, (_) => _probe());
  }

  Future<void> _probe() async {
    if (_isChecking) return;
    _isChecking = true;

    bool reachable;
    try {
      // Cheap pre-check: if there's no interface at all, skip the HTTP call.
      final conn = await Connectivity().checkConnectivity();
      if (conn.contains(ConnectivityResult.none)) {
        reachable = false;
      } else {
        final res = await http
            .get(Uri.parse(_probeUrl))
            .timeout(_probeTimeout);
        reachable = res.statusCode == 204 || res.statusCode == 200;
      }
    } catch (_) {
      reachable = false;
    }

    _isChecking = false;
    if (reachable != _hasInternet) {
      _hasInternet = reachable;
      notifyListeners();
    }
  }

  /// Manual "Try Again" trigger from the no-internet screen.
  Future<void> retryConnection() async {
    _isChecking = true;
    notifyListeners();
    await _probe();
    if (_isChecking) {
      _isChecking = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
