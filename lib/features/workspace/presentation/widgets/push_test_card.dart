import 'package:flutter/material.dart';

import '../../../../core/notifications/notification_service.dart';

/// Lets a signed-in user send a real FCM test to the currently used device.
class PushTestCard extends StatefulWidget {
  const PushTestCard({super.key});

  @override
  State<PushTestCard> createState() => _PushTestCardState();
}

class _PushTestCardState extends State<PushTestCard> {
  bool _sending = false;

  Future<void> _send() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final result = await NotificationService.sendTestPush();
      if (!mounted) return;
      final devices = (result['deviceCount'] as num?)?.toInt() ?? 0;
      final accepted = (result['sent'] as num?)?.toInt() ?? 0;
      final message = devices == 0
          ? 'No device is registered yet. Allow notifications and try again.'
          : accepted == 0
          ? 'The push service did not accept this notification. Check the backend logs.'
          : 'Push accepted for $accepted device${accepted == 1 ? '' : 's'}. Check the notification shade.';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
            backgroundColor: accepted > 0
                ? const Color(0xFF17694F)
                : Theme.of(context).colorScheme.error,
          ),
        );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF6EDF2),
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(
              Icons.notifications_active_outlined,
              color: Color(0xFF74144F),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Test this device',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 3),
                Text(
                  'Send a push notification to this phone now.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF68758A)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded, size: 17),
            label: Text(_sending ? 'Sending' : 'Send test'),
          ),
        ],
      ),
    ),
  );
}
