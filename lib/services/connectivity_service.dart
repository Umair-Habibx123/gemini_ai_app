import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityService with ChangeNotifier {
  bool _hasInternet = true;

  bool get hasInternet => _hasInternet;

  ConnectivityService() {
    _init();
  }

  Future<void> _init() async {
    // Initial check
    await _checkConnectivity();
    
    // Listen for changes
    Connectivity().onConnectivityChanged.listen((result) {
      _checkConnectivity();
    });
  }

  Future<void> _checkConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    var newStatus = !connectivityResult.contains(ConnectivityResult.none);
    
    if (newStatus != _hasInternet) {
      _hasInternet = newStatus;
      notifyListeners();
    }
  }

  Future<void> retryConnection() async {
    await _checkConnectivity();
  }
}