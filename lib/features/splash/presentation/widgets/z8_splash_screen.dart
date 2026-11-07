import 'package:flutter/material.dart';

/// Branded startup and session-recovery screen shared by the app entry flow.
class Z8SplashScreen extends StatelessWidget {
  const Z8SplashScreen({
    super.key,
    this.message,
    this.onRetry,
    this.loading = true,
  });

  final String? message;
  final VoidCallback? onRetry;
  final bool loading;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF5F0E8),
    body: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/images/splash.jpeg', fit: BoxFit.cover),
        if (message != null)
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              minimum: const EdgeInsets.all(20),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(message!, textAlign: TextAlign.center),
                      if (onRetry != null) ...[
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: onRetry,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Try again'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          )
        else if (loading)
          const Positioned(
            left: 0,
            right: 0,
            bottom: 34,
            child: Center(
              child: SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFF71164F),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
