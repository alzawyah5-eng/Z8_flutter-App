import 'dart:async';

import 'package:flutter/material.dart';

/// Displays issuer returned PAN/CVV briefly, then masks it and masks it again
/// whenever the app leaves the foreground.
class SecureCardDetailsDialog extends StatefulWidget {
  const SecureCardDetailsDialog({required this.card, super.key});

  final Map<String, dynamic> card;

  @override
  State<SecureCardDetailsDialog> createState() =>
      _SecureCardDetailsDialogState();
}

class _SecureCardDetailsDialogState extends State<SecureCardDetailsDialog>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _armTimer();
  }

  void _armTimer() {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 30), _hide);
  }

  void _hide() {
    if (!mounted || !_visible) return;
    setState(() => _visible = false);
    _timer?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _hide();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Secure card details'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_visible)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('Details hidden for your security.'),
          ),
        _row('Card number', widget.card['card_no']),
        _row('Expiry', widget.card['expiry']),
        _row('CVV', widget.card['cvv']),
        if (widget.card['cvv_unavailable'] == true)
          const Text('PhotonPay did not return the CVV.'),
      ],
    ),
    actions: [
      if (!_visible &&
          [
            'card_no',
            'expiry',
            'cvv',
          ].any((key) => '${widget.card[key] ?? ''}'.isNotEmpty))
        TextButton(
          onPressed: () {
            setState(() => _visible = true);
            _armTimer();
          },
          child: const Text('Show for 30 seconds'),
        ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  );

  Widget _row(String label, dynamic value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        SelectableText(
          _visible && value?.toString().isNotEmpty == true
              ? value.toString()
              : '••••',
        ),
      ],
    ),
  );
}
