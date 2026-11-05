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
  bool _checking = true;
  bool _connected = false;
  bool _showWelcome = false;
  bool _receivedStatusEvent = false;

  @override
  void initState() {
    super.initState();
    _subscription = _connection.onStatusChange.listen(_onStatus);
    _checkInitial();
  }

  Future<void> _checkInitial() async {
    final connected = await _connection.hasInternetAccess;
    if (!mounted || _receivedStatusEvent) return;
    setState(() {
      _checking = false;
      _connected = connected;
    });
  }

  void _onStatus(InternetStatus status) {
    final connected = status == InternetStatus.connected;
    _receivedStatusEvent = true;
    final isReconnect = !_checking && !_connected && connected;
    if (!mounted) return;
    _welcomeTimer?.cancel();
    setState(() {
      _checking = false;
      _connected = connected;
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
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_checking || !_connected)
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
