part of '../../workspace_page.dart';

extension _WorkspaceCardVerificationSections on _WorkspacePageState {
  Future<String?> _ask(String label, {String initial = ''}) async {
    final controller = TextEditingController(text: initial);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    await _waitForDialogExitAnimation();
    controller.dispose();
    return value;
  }

  Future<void> _cardActions(Map<String, dynamic> card) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(_recordTitle(card)),
              subtitle: Text(_recordSubtitle(card)),
            ),
            for (final item
                in (card['status'] == 'frozen' ? ['unfreeze'] : ['freeze']))
              ListTile(
                leading: const Icon(Icons.pause_circle_outline),
                title: Text(item == 'freeze' ? 'Freeze card' : 'Unfreeze card'),
                onTap: () => Navigator.pop(context, item),
              ),
            if (!_admin)
              ListTile(
                leading: const Icon(Icons.lock_open),
                title: const Text('Unblock CVV'),
                onTap: () => Navigator.pop(context, 'unblock_cvv'),
              ),
            if (card['card_type'] == 'recharge' && card['status'] == 'active')
              ListTile(
                leading: const Icon(Icons.add_card),
                title: const Text('Add credit'),
                onTap: () => Navigator.pop(context, 'top_up'),
              ),
            if (_admin) ...[
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit card name'),
                onTap: () => Navigator.pop(context, 'edit_card'),
              ),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Assign to account'),
                onTap: () => Navigator.pop(context, 'assign'),
              ),
            ],
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: const Text('View secure card details'),
              onTap: () => Navigator.pop(context, 'reveal'),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Refresh card details'),
              onTap: () => Navigator.pop(context, 'refresh'),
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_rounded),
              title: const Text('View card activity'),
              onTap: () => Navigator.pop(context, 'card_activity'),
            ),
            if (_admin)
              ListTile(
                leading: const Icon(Icons.cancel_outlined),
                title: const Text('Cancel card'),
                onTap: () => Navigator.pop(context, 'cancel'),
              ),
          ],
        ),
      ),
    );
    if (action == 'reveal') {
      final isOwner =
          '${card['owner_email'] ?? ''}'.toLowerCase() == _email.toLowerCase();
      final reason = _admin && !isOwner
          ? await _ask(
              'Reason for viewing this client card (10 characters minimum)',
            )
          : null;
      if (_admin && !isOwner && (reason == null || reason.trim().length < 10))
        return;
      try {
        final result = await BackendApi.photonPayAction(
          await _token(),
          'detail',
          payload: {
            'recordId': card['id'],
            if (reason != null) 'reason': reason,
          },
        );
        if (result['error'] != null) throw Exception(result['error']);
        final detail = Map<String, dynamic>.from(result['card'] as Map? ?? {});
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Secure card details'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailRow('Card number', detail['card_no']),
                _detailRow('Expiry', detail['expiry']),
                _detailRow('CVV', detail['cvv']),
                if (detail['cvv_unavailable'] == true)
                  const Text('PhotonPay did not return the CVV.'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      } catch (error) {
        if (mounted) _updateWorkspace(() => _error = _friendly(error));
      }
      return;
    }
    if (action == 'top_up') {
      await _topUpCard(card);
      return;
    }
    if (action == 'edit_card') {
      await _editCard(card);
      return;
    }
    if (action == 'assign') {
      final email = await _ask(
        'Client account email',
        initial: '${card['owner_email'] ?? ''}',
      );
      if (email != null)
        await _call('assign', {
          'recordId': card['id'],
          'ownerEmail': email.trim().toLowerCase(),
        });
      return;
    }
    if (action == 'card_activity') {
      try {
        final page = await BackendApi.queryEntity(
          await _token(),
          'CardTransaction',
          filter: {'card_id': card['id']},
          sort: '-occurred_at',
          limit: 50,
        );
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('${_recordTitle(card)} · Activity'),
            content: SizedBox(
              width: 500,
              height: MediaQuery.sizeOf(context).height * .55,
              child: ListView(
                children: [
                  for (final item in _items(page))
                    ListTile(
                      title: Text(_recordTitle(item)),
                      subtitle: Text(_recordSubtitle(item)),
                    ),
                  if (_items(page).isEmpty)
                    const ListTile(
                      title: Text('No activity for this card yet.'),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      } catch (error) {
        if (mounted) _updateWorkspace(() => _error = _friendly(error));
      }
      return;
    }
    if (action == 'cancel') {
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Cancel this card permanently?'),
          content: const Text(
            'The card cannot be used again after cancellation.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep card'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Cancel card'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    if (action != null) await _call(action, {'recordId': card['id']});
  }

  Future<void> _editCard(Map<String, dynamic> card) => _formDialog(
    'Edit card controls',
    const [
      _FieldSpec('nickname', 'Card name'),
      _FieldSpec(
        'transactionLimitType',
        'Transaction limit: limited or unlimited',
      ),
      _FieldSpec('transactionLimit', 'Limit change amount USD'),
      _FieldSpec(
        'transactionLimitChangeType',
        'Change direction: increase or decrease',
      ),
    ],
    (values) async {
      final payload = <String, Object?>{'recordId': card['id']};
      for (final entry in values.entries) {
        if (entry.value.trim().isNotEmpty)
          payload[entry.key] = entry.value.trim();
      }
      final result = await BackendApi.photonPayAction(
        await _token(),
        'update_card',
        payload: payload,
      );
      if (result['error'] != null) throw Exception(result['error']);
      if (mounted)
        _updateWorkspace(() {
          _notice = 'Card settings updated.';
          _navigationCubit.refresh();
        });
    },
    initialValues: {'nickname': card['nickname']},
  );

  Future<void> _topUpCard(Map<String, dynamic> card) async {
    final amountText = await _ask('Amount to add in USD');
    final amount = double.tryParse(amountText ?? '');
    if (amount == null || amount <= 0) {
      if (amountText != null && mounted)
        _updateWorkspace(() => _error = 'Enter a valid amount.');
      return;
    }
    try {
      final token = await _token();
      final quote = await BackendApi.photonPayAction(
        token,
        'top_up_quote',
        payload: {'recordId': card['id'], 'amount': amount},
      );
      if (quote['error'] != null) throw Exception(quote['error']);
      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm card top-up'),
          content: Text(
            'Load USD ${quote['recharge_amount'] ?? amount}. Fee: ${quote['fee'] ?? 'shown by PhotonPay'}. This uses the available programme/client balance.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      final result = await BackendApi.photonPayAction(
        token,
        'top_up_confirm',
        payload: {'recordId': card['id'], 'requestId': quote['request_id']},
      );
      if (result['error'] != null) throw Exception(result['error']);
      if (mounted)
        _updateWorkspace(() {
          _notice = 'Card top-up submitted.';
          _navigationCubit.refresh();
        });
    } catch (error) {
      if (mounted) _updateWorkspace(() => _error = _friendly(error));
    }
  }

  Widget _detailRow(String label, dynamic value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        SelectableText(
          value?.toString().isNotEmpty == true
              ? value.toString()
              : 'Unavailable',
        ),
      ],
    ),
  );

  Widget _verification(Map<String, dynamic> data) {
    final app = data['application'] as Map?;
    final identity = data['identity'] as Map?;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          'Identity verification',
          'Submit your details for admin review before they are sent to PhotonPay.',
        ),
        _statusCard(
          'Current status',
          '${identity?['status'] ?? app?['status'] ?? 'Not started'}',
        ),
        if (app?['review_note'] != null) _message('${app?['review_note']}'),
        if (app?['status'] != 'submitted' &&
            app?['status'] != 'approved' &&
            identity?['status'] != 'verified')
          _actionButton(
            'Start or resubmit verification',
            Icons.verified_user_outlined,
            _verificationForm,
          ),
        if (app != null) _recordList('Application', [app]),
      ],
    );
  }

  Future<void> _verificationForm() async {
    final imagePicker = ImagePicker();
    XFile? front, back;
    final selected = <String, String>{};
    final fields = <_FieldSpec>[
      const _FieldSpec('firstName', 'First name', required: true),
      const _FieldSpec('lastName', 'Last name', required: true),
      const _FieldSpec(
        'dateOfBirth',
        'Date of birth',
        required: true,
        date: true,
      ),
      const _FieldSpec(
        'nationalityCountryCode',
        'Nationality',
        required: true,
        country: true,
      ),
      const _FieldSpec(
        'mobilePrefix',
        'Country calling code',
        required: true,
        dial: true,
      ),
      const _FieldSpec('mobile', 'Mobile number', required: true),
      const _FieldSpec('residentialAddress', 'Street address', required: true),
      const _FieldSpec('residentialCity', 'City', required: true),
      const _FieldSpec('residentialState', 'State / province'),
      const _FieldSpec('residentialPostalCode', 'Postal code', required: true),
      const _FieldSpec(
        'residentialCountryCode',
        'Residence country',
        required: true,
        country: true,
      ),
      const _FieldSpec(
        'certType',
        'ID document type',
        required: true,
        options: [
          _FieldOption('passport', 'Passport'),
          _FieldOption('id_card', 'National ID card'),
          _FieldOption('resident_permit', 'Residence permit'),
        ],
      ),
      const _FieldSpec('certId', 'ID number', required: true),
      const _FieldSpec(
        'certCountryCode',
        'ID issuing country',
        required: true,
        country: true,
      ),
      const _FieldSpec(
        'deviceCountry',
        'Country you are in now',
        required: true,
        country: true,
      ),
    ];
    final controllers = {
      for (final f in fields) f.key: TextEditingController(),
    };
    final key = GlobalKey<FormState>();
    String? photoWarning;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Verify your identity'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Form(
                key: key,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final f in fields)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _styledFormField(
                          f,
                          controllers[f.key]!,
                          setDialog,
                        ),
                      ),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () async {
                            front = await imagePicker.pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 80,
                            );
                            setDialog(() {});
                          },
                          icon: const Icon(Icons.image),
                          label: Text(
                            front == null
                                ? 'Front / passport page'
                                : 'Front selected',
                          ),
                        ),
                        if (controllers['certType']?.text != 'passport')
                          OutlinedButton.icon(
                            onPressed: () async {
                              back = await imagePicker.pickImage(
                                source: ImageSource.gallery,
                                imageQuality: 80,
                              );
                              setDialog(() {});
                            },
                            icon: const Icon(Icons.image),
                            label: Text(
                              back == null ? 'Back of ID' : 'Back selected',
                            ),
                          ),
                      ],
                    ),
                    if (photoWarning != null)
                      Text(
                        photoWarning!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (!key.currentState!.validate()) return;
                if (front == null ||
                    (controllers['certType']!.text != 'passport' &&
                        back == null)) {
                  setDialog(
                    () => photoWarning = 'Choose the required ID photos.',
                  );
                  return;
                }
                setDialog(() => photoWarning = 'Uploading privately…');
                try {
                  final token = await _token();
                  final frontData = base64Encode(await front!.readAsBytes());
                  final frontResult = await BackendApi.photonPayAction(
                    token,
                    'store_id_photo',
                    payload: {
                      'dataBase64': frontData,
                      'fileName': front!.name,
                      'mimeType': front!.mimeType ?? 'image/jpeg',
                    },
                  );
                  final backResult = back == null
                      ? <String, dynamic>{}
                      : await BackendApi.photonPayAction(
                          token,
                          'store_id_photo',
                          payload: {
                            'dataBase64': base64Encode(
                              await back!.readAsBytes(),
                            ),
                            'fileName': back!.name,
                            'mimeType': back!.mimeType ?? 'image/jpeg',
                          },
                        );
                  selected.addAll({
                    for (final e in controllers.entries)
                      e.key: e.value.text.trim(),
                  });
                  final result = await BackendApi.photonPayAction(
                    token,
                    'submit_registration',
                    payload: {
                      ...selected,
                      'frontPhotoToken': frontResult['photo_token'],
                      'backPhotoToken': backResult['photo_token'] ?? '',
                    },
                  );
                  if (result['error'] != null) throw Exception(result['error']);
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  if (mounted)
                    _updateWorkspace(() {
                      _notice = 'Verification submitted for review.';
                      _navigationCubit.refresh();
                    });
                } catch (error) {
                  setDialog(() => photoWarning = _friendly(error));
                }
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
    await _waitForDialogExitAnimation();
    for (final c in controllers.values) {
      c.dispose();
    }
  }
}
