import 'dart:async';

import 'package:flutter/material.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

import '../theme/app_theme.dart';

class NetworkStatusGate extends StatefulWidget {
  const NetworkStatusGate({required this.child, super.key});

  final Widget child;

  @override
  State<NetworkStatusGate> createState() => _NetworkStatusGateState();
}

class _NetworkStatusGateState extends State<NetworkStatusGate> {
  final InternetConnection _connection = InternetConnection();
  StreamSubscription<InternetStatus>? _subscription;
  Timer? _welcomeTimer;
  Timer? _offlineTimer;
  Timer? _retryTimer;
  bool _checking = true;
  bool _connected = true;
  bool _showWelcome = false;

  @override
  void initState() {
    super.initState();
    _subscription = _connection.onStatusChange.listen(_onStatus);
    _checkInitial();
    _retryTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_connected) _checkConnection();
    });
  }

  Future<void> _checkInitial() async {
    final connected = await _probe();
    if (!mounted) return;
    setState(() => _checking = false);
    if (connected) {
      _setConnected();
    } else {
      _scheduleOfflineConfirmation();
    }
  }

  void _onStatus(InternetStatus status) {
    final connected = status == InternetStatus.connected;
    if (connected) _setConnected();
    else _scheduleOfflineConfirmation();
  }

  Future<bool> _probe() async {
    try {
      return await _connection.hasInternetAccess.timeout(
        const Duration(seconds: 5),
        onTimeout: () => false,
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> _checkConnection() async {
    if (await _probe()) _setConnected();
  }

  void _scheduleOfflineConfirmation() {
    _offlineTimer?.cancel();
    _offlineTimer = Timer(const Duration(seconds: 3), () async {
      if (!mounted) return;
      if (await _probe()) {
        _setConnected();
        return;
      }
      if (mounted) {
        setState(() {
          _checking = false;
          _connected = false;
        });
      }
    });
  }

  void _setConnected() {
    if (!mounted) return;
    _offlineTimer?.cancel();
    final isReconnect = !_checking && !_connected;
    _welcomeTimer?.cancel();
    setState(() {
      _checking = false;
      _connected = true;
      _showWelcome = isReconnect;
    });
    if (isReconnect) {
      _welcomeTimer = Timer(const Duration(milliseconds: 2000), () {
        if (mounted) setState(() => _showWelcome = false);
      });
    }
  }

  @override
  void dispose() {
    _welcomeTimer?.cancel();
    _offlineTimer?.cancel();
    _retryTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (!_checking && !_connected)
          Positioned.fill(
            child: Scaffold(
              backgroundColor: AppTheme.canvas,
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off_rounded, size: 48, color: AppTheme.plum),
                    const SizedBox(height: 18),
                    Text(
                      _checking ? 'Checking connection...' : 'Disconnected',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppTheme.ink),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Waiting for an internet connection',
                      style: TextStyle(color: AppTheme.muted),
                    ),
                    const SizedBox(height: 24),
                    const CircularProgressIndicator(),
                  ],
                ),
              ),
            ),
          ),
        if (_showWelcome)
          const Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: SafeArea(
              top: false,
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.all(Radius.circular(12)),
                color: AppTheme.plum,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  child: Row(
                    children: [
                      Icon(Icons.wifi_rounded, color: Colors.white),
                      SizedBox(width: 10),
                      Text(
                        'Welcome back!',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
