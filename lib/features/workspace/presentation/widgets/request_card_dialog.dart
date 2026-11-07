import 'package:flutter/material.dart';

enum RequestCardDialogResult { requested, addFunds }

/// Request-card flow kept separate from the workspace layout and reusable
/// wherever a verified client can start a card request.
class RequestCardDialog extends StatefulWidget {
  const RequestCardDialog({
    required this.requestState,
    required this.onSubmit,
    super.key,
  });

  final Map<String, dynamic> requestState;
  final Future<void> Function(Map<String, Object?> payload) onSubmit;

  @override
  State<RequestCardDialog> createState() => _RequestCardDialogState();
}

class _RequestCardDialogState extends State<RequestCardDialog> {
  static const _purposes = <(String, String, IconData)>[
    ('online_shopping', 'Online shopping', Icons.shopping_bag_outlined),
    ('advertising', 'Advertising', Icons.campaign_outlined),
    ('subscriptions', 'Subscriptions', Icons.autorenew_rounded),
    ('travel', 'Travel', Icons.flight_takeoff_rounded),
    ('business_expenses', 'Business expenses', Icons.business_center_outlined),
    ('other', 'Other', Icons.more_horiz_rounded),
  ];

  late final double _minimum;
  late final double _available;
  late final List<Map<String, dynamic>> _tiers;
  late final Set<String> _eligible;
  late final TextEditingController _amount;
  final _purposeDetail = TextEditingController();
  String? _selectedTier;
  String? _selectedPurpose;
  String? _error;
  bool _busy = false;
  bool _complete = false;

  @override
  void initState() {
    super.initState();
    final state = widget.requestState;
    _minimum = double.tryParse('${state['min_amount']}') ?? 20;
    _available = double.tryParse('${state['available']}') ?? 0;
    _tiers = (state['ladder'] as List? ?? [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    _eligible = (state['eligible_tiers'] as List? ?? [])
        .map((item) => '$item')
        .toSet();
    final requestedTier = '${state['tier'] ?? ''}';
    _selectedTier = _eligible.contains(requestedTier)
        ? requestedTier
        : _tiers
              .map((tier) => '${tier['id']}')
              .where(_eligible.contains)
              .firstOrNull;
    _amount = TextEditingController(text: _minimum.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _amount.dispose();
    _purposeDetail.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amount.text.trim());
    final purpose = _selectedPurpose;
    if (purpose == null) {
      setState(() => _error = 'Choose what you’ll use the card for.');
      return;
    }
    if (purpose == 'other' && _purposeDetail.text.trim().length < 3) {
      setState(() => _error = 'Add a short description for this purpose.');
      return;
    }
    if (amount == null || amount < _minimum) {
      setState(
        () => _error = 'Enter at least USD ${_minimum.toStringAsFixed(2)}.',
      );
      return;
    }
    if (amount > _available) {
      setState(
        () => _error =
            'Available balance is USD ${_available.toStringAsFixed(2)}.',
      );
      return;
    }
    if (_selectedTier == null) {
      setState(() => _error = 'Choose an available card tier.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit({
        'amount': amount,
        'purpose': purpose,
        'purposeDetail': purpose == 'other' ? _purposeDetail.text.trim() : '',
        'tier': _selectedTier,
      });
      if (mounted) setState(() => _complete = true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.requestState;
    final canRequest = state['can_request'] == true;
    return AlertDialog(
      scrollable: false,
      title: Row(
        children: [
          Icon(
            _complete
                ? Icons.check_circle_outline_rounded
                : Icons.credit_card_rounded,
            color: _complete
                ? const Color(0xFF167653)
                : const Color(0xFF74144F),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(_complete ? 'Request sent' : 'Request a card')),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: _complete
            ? Text(
                'USD ${double.parse(_amount.text).toStringAsFixed(2)} has been reserved from your available balance. Your request is ready for administrator review.',
              )
            : !canRequest && state['needs_funds'] == true
            ? _fundingNeededContent(state)
            : !canRequest
            ? Text(
                '${state['reason'] ?? 'Card requests are not available right now.'}',
              )
            : _formWithActions(),
      ),
      actions: _complete
          ? [
              FilledButton(
                onPressed: () =>
                    Navigator.pop(context, RequestCardDialogResult.requested),
                child: const Text('Done'),
              ),
            ]
          : !canRequest && state['needs_funds'] == true
          ? [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Not now'),
              ),
              FilledButton.icon(
                onPressed: () =>
                    Navigator.pop(context, RequestCardDialogResult.addFunds),
                icon: const Icon(Icons.savings_rounded),
                label: const Text('Add funds'),
              ),
            ]
          : !canRequest
          ? [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ]
          : [],
    );
  }

  Widget _formWithActions() => SingleChildScrollView(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _formContents(),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _busy ? null : _submit,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(_busy ? 'Sending…' : 'Send request'),
            ),
          ],
        ),
      ],
    ),
  );
  Widget _fundingNeededContent(Map<String, dynamic> state) {
    final ladder = state['ladder'] as List? ?? const [];
    final tier = '${state['tier'] ?? ''}';
    final first = ladder.whereType<Map>().firstOrNull;
    final firstName = '${first?['name'] ?? first?['id'] ?? 'first card'}';
    final firstAmount = double.tryParse('${first?['from']}') ?? _minimum;
    final deposited = double.tryParse('${state['deposited']}') ?? 0;
    final message = tier.isEmpty && first != null
        ? 'Your first card, $firstName, is available once you have deposited USD ${firstAmount.toStringAsFixed(2)} in total. You have deposited USD ${deposited.toStringAsFixed(2)} so far.'
        : 'A new card needs at least USD ${_minimum.toStringAsFixed(2)} available in your account. Your available balance is USD ${_available.toStringAsFixed(2)}.';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.account_balance_wallet_outlined, size: 28),
        const SizedBox(height: 12),
        const Text(
          'Add funds first',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(message),
      ],
    );
  }

  Widget _formContents() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        'Virtual USD card · From your available balance',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 16),
      if (_tiers.isNotEmpty) ...[
        const _FieldLabel('Card tier'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tier in _tiers)
              _TierChoice(
                name: '${tier['name'] ?? tier['id']}',
                minimum: double.tryParse('${tier['from']}') ?? 0,
                selected: _selectedTier == '${tier['id']}',
                available: _eligible.contains('${tier['id']}'),
                onTap: () => setState(() {
                  _selectedTier = '${tier['id']}';
                  _error = null;
                }),
              ),
          ],
        ),
        const SizedBox(height: 16),
      ],
      const _FieldLabel('What will you use this card for?'),
      const SizedBox(height: 8),
      ..._purposes.map(
        (purpose) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _PurposeChoice(
            icon: purpose.$3,
            title: purpose.$2,
            selected: _selectedPurpose == purpose.$1,
            onTap: () => setState(() {
              _selectedPurpose = purpose.$1;
              _error = null;
            }),
          ),
        ),
      ),
      if (_selectedPurpose == 'other') ...[
        const SizedBox(height: 6),
        TextField(
          controller: _purposeDetail,
          maxLength: 60,
          decoration: const InputDecoration(
            labelText: 'Purpose details',
            hintText: 'e.g. Supplier payments',
          ),
        ),
      ],
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F1F4),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          children: [
            const Expanded(child: Text('Available balance')),
            Text(
              'USD ${_available.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _amount,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: 'Amount to put on the card (USD)',
          helperText:
              'Minimum USD ${_minimum.toStringAsFixed(2)} · Maximum USD ${_available.toStringAsFixed(2)}',
        ),
        onChanged: (_) => setState(() => _error = null),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 7,
        children: [
          for (final value in <double>{
            _minimum,
            50,
            100,
            250,
            _available,
          }.where((value) => value >= _minimum && value <= _available))
            ActionChip(
              label: Text('USD ${value.toStringAsFixed(0)}'),
              onPressed: () => setState(() {
                _amount.text = value.toStringAsFixed(2);
                _error = null;
              }),
            ),
        ],
      ),
      if (_error != null) ...[
        const SizedBox(height: 10),
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
    ],
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
  );
}

class _TierChoice extends StatelessWidget {
  const _TierChoice({
    required this.name,
    required this.minimum,
    required this.selected,
    required this.available,
    required this.onTap,
  });
  final String name;
  final double minimum;
  final bool selected;
  final bool available;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = switch (name.toLowerCase()) {
      'emerald' => const [Color(0xFF126E58), Color(0xFF0E3F3B)],
      'crimson' => const [Color(0xFF8B2C35), Color(0xFF361B2D)],
      _ => const [Color(0xFF4D315C), Color(0xFF201E36)],
    };
    return InkWell(
      onTap: available ? onTap : null,
      borderRadius: BorderRadius.circular(7),
      child: Opacity(
        opacity: available ? 1 : .48,
        child: Container(
          width: 137,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: selected ? const Color(0xFFD9B56D) : Colors.white24,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.contactless_rounded,
                color: Colors.white70,
                size: 17,
              ),
              const SizedBox(height: 13),
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                available
                    ? 'From USD ${minimum.toStringAsFixed(0)}'
                    : 'Not unlocked',
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PurposeChoice extends StatelessWidget {
  const _PurposeChoice({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? const Color(0xFFF6EDF2) : Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(7),
      side: BorderSide(
        color: selected ? const Color(0xFF74144F) : const Color(0xFFE6E2E7),
      ),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(7),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        child: Row(
          children: [
            Icon(icon, size: 19, color: const Color(0xFF74144F)),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 13))),
            if (selected)
              const Icon(
                Icons.check_circle,
                size: 17,
                color: Color(0xFF74144F),
              ),
          ],
        ),
      ),
    ),
  );
}
