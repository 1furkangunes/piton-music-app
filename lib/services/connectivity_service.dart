import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityService {
  static final Connectivity _connectivity = Connectivity();
  static bool _isConnected = true;
  static bool _isInitialized = false;
  static bool _isPluginAvailable = true;
  static StreamSubscription<List<ConnectivityResult>>?
  _connectivitySubscription;

  static final StreamController<bool> _connectivityController =
      StreamController<bool>.broadcast();

  static Stream<bool> get connectivityStream => _connectivityController.stream;
  static bool get isConnected => _isConnected;
  static bool get isPluginAvailable => _isPluginAvailable;

  static bool _forceOfflineMode = false;
  static bool get isTestMode => _forceOfflineMode;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      _isConnected = _isConnectedFromResult(connectivityResult);
      _isPluginAvailable = true;

      _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
        List<ConnectivityResult> results,
      ) {
        final bool wasConnected = _isConnected;
        _isConnected = _isConnectedFromResults(results);

        if (_forceOfflineMode) {
          _isConnected = false;
        }

        if (wasConnected != _isConnected) {
          _connectivityController.add(_isConnected);
        }
      });

      _isInitialized = true;
    } catch (e) {
      debugPrint('❌ ConnectivityService initialization error: $e');

      _isPluginAvailable = false;
      _isInitialized = true;

      try {
        _isConnected = await _testRealInternetConnection();
      } catch (e) {
        _isConnected = false;
      }
    }
  }

  static bool _isConnectedFromResults(List<ConnectivityResult> results) {
    return results.any((result) => _isConnectedFromResult([result]));
  }

  static bool _isConnectedFromResult(List<ConnectivityResult> results) {
    return results.any(
      (result) =>
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.ethernet ||
          result == ConnectivityResult.vpn ||
          result == ConnectivityResult.other,
    );
  }

  static Future<bool> checkConnection() async {
    if (!_isPluginAvailable) {
      if (_forceOfflineMode) {
        return false;
      }

      final realConnection = await _testRealInternetConnection();

      if (_isConnected != realConnection) {
        _isConnected = realConnection;
        _connectivityController.add(_isConnected);
      }

      return realConnection;
    }

    try {
      final connectivityResult = await _connectivity
          .checkConnectivity()
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () => [ConnectivityResult.none],
          );

      final isCurrentlyConnected = _isConnectedFromResult(connectivityResult);

      final finalConnection = _forceOfflineMode ? false : isCurrentlyConnected;

      if (_isConnected != finalConnection) {
        _isConnected = finalConnection;
        _connectivityController.add(_isConnected);
      }

      return _isConnected;
    } catch (e) {
      debugPrint('❌ Connection check error: $e');
      final connectionStatus = !_forceOfflineMode;
      return connectionStatus;
    }
  }

  static void showConnectivitySnackBar(BuildContext context) {
    if (!context.mounted) return;

    if (!_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.wifi_off, color: Colors.white),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'İnternete bağlı değilsin',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'İndirilen müzikleri dinleyebilirsin',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange.shade600,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          action: SnackBarAction(
            label: 'İndirilenler',
            textColor: Colors.white,
            onPressed: () {
              Navigator.pushNamed(context, '/downloads');
            },
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.wifi, color: Colors.white),
              const SizedBox(width: 12),
              const Text(
                'İnternet bağlantısı geri geldi!',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  static Widget buildOfflineIndicator() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: Colors.orange.shade600,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, color: Colors.white, size: 18),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Çevrimdışısın',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'İndirdiğin müzikleri dinleyebilirsin',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static bool requiresInternet({
    required BuildContext context,
    String? message,
    bool showSnackBar = true,
  }) {
    if (!_isConnected) {
      if (showSnackBar && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message ?? 'Bu işlem için internet bağlantısı gerekli',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
      return false;
    }
    return true;
  }

  static void dispose() {
    _connectivitySubscription?.cancel();
    _connectivityController.close();
  }

  static void setOfflineMode(bool offline) {
    _forceOfflineMode = offline;
    _isConnected = !offline;
    _connectivityController.add(_isConnected);
  }

  static void resetToOnlineMode() {
    setOfflineMode(false);
  }

  static Future<void> testConnectivity() async {
    await checkConnection();
  }

  static Future<bool> _testRealInternetConnection() async {
    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 3), onTimeout: () => []);

      final hasConnection =
          result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      return hasConnection;
    } catch (e) {
      return false;
    }
  }
}
