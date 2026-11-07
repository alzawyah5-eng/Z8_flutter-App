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
    final cancelled = '${card['status']}'.toLowerCase() == 'cancelled';
    var cvvBlocked = card['cvv_blocked'] == true;
    if (!_admin && !cancelled && '${card['photon_card_id'] ?? ''}'.isNotEmpty) {
      if (mounted) setState(() => _busyCardId = '${card['id']}');
      try {
        final refreshed = await BackendApi.photonPayAction(
          await _token(),
          'refresh',
          payload: {'recordId': card['id']},
        );
        cvvBlocked = refreshed['cvv_blocked'] == true;
      } catch (_) {
        // Keep card controls available when PhotonPay's status endpoint is offline.
      } finally {
        if (mounted) setState(() => _busyCardId = null);
      }
    }
    if (!mounted) return;
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
            if (!cancelled)
              for (final item
                  in (card['status'] == 'frozen' ? ['unfreeze'] : ['freeze']))
                ListTile(
                  leading: const Icon(Icons.pause_circle_outline),
                  title: Text(
                    item == 'freeze' ? 'Freeze card' : 'Unfreeze card',
                  ),
                  onTap: () => Navigator.pop(context, item),
                ),
            if (!_admin && cvvBlocked)
              ListTile(
                leading: const Icon(Icons.lock_open),
                title: const Text('Unblock CVV'),
                onTap: () => Navigator.pop(context, 'unblock_cvv'),
              ),
            if (!cancelled &&
                card['card_type'] == 'recharge' &&
                card['status'] == 'active')
              ListTile(
                leading: const Icon(Icons.add_card),
                title: const Text('Add credit'),
                onTap: () => Navigator.pop(context, 'top_up'),
              ),
            if (_admin) ...[
              if ('${card['photon_card_id'] ?? ''}'.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.science_outlined),
                  title: const Text('Sandbox test transaction'),
                  onTap: () => Navigator.pop(context, 'sandbox_txn'),
                ),
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
            if (!cancelled)
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
            if (_admin && !cancelled)
              ListTile(
                leading: const Icon(Icons.cancel_outlined),
                title: const Text('Cancel card'),
                onTap: () => Navigator.pop(context, 'cancel'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    setState(() => _busyCardId = '${card['id']}');
    try {
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
          builder: (context) => SecureCardDetailsDialog(card: detail),
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
    if (action == 'sandbox_txn') {
      await _sandboxTransaction(card);
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
    await _call(action, {'recordId': card['id']});
    } finally {
      if (mounted) setState(() => _busyCardId = null);
    }
  }

  Future<void> _sandboxTransaction(Map<String, dynamic> card) => _formDialog(
    'Sandbox test transaction',
    const [
      _FieldSpec(
        'txnType',
        'Transaction type',
        required: true,
        options: [
          _FieldOption('auth', 'Payment (auth)'),
          _FieldOption('void', 'Void a payment'),
          _FieldOption('refund', 'Refund a payment'),
        ],
      ),
      _FieldSpec(
        'amount',
        'Amount',
        required: true,
        keyboardType: TextInputType.numberWithOptions(decimal: true),
      ),
      _FieldSpec('merchantName', 'Merchant name', required: true),
      _FieldSpec(
        'mcc',
        'Merchant category code',
        helperText: 'Four digits, for example 5999.',
      ),
      _FieldSpec(
        'originTransactionId',
        'Original payment ID (void/refund)',
        helperText: 'Required for void and refund transactions.',
      ),
    ],
    (values) async {
      final amount = double.tryParse(values['amount'] ?? '');
      if (amount == null || amount <= 0) {
        throw Exception('Enter an amount greater than zero.');
      }
      final txnType = values['txnType'] ?? '';
      if (txnType != 'auth' &&
          (values['originTransactionId'] ?? '').trim().isEmpty) {
        throw Exception('Enter the original payment ID for a void or refund.');
      }
      final result = await BackendApi.photonPayAction(
        await _token(),
        'sandbox_txn',
        payload: {
          'recordId': card['id'],
          'txnType': txnType,
          'amount': amount,
          'merchantName': values['merchantName'] ?? '',
          'mcc': values['mcc'] ?? '',
          'originTransactionId': values['originTransactionId'] ?? '',
        },
      );
      if (result['error'] != null) throw Exception(result['error']);
      if (mounted) {
        _updateWorkspace(() {
          _notice =
              'Sandbox test transaction sent: ${result['request_id'] ?? 'accepted'}.';
          _reloadSection();
        });
      }
    },
    initialValues: const {
      'txnType': 'auth',
      'amount': '10',
      'merchantName': 'Z8 sandbox test',
      'mcc': '5999',
    },
  );

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
          _reloadSection();
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
          _reloadSection();
        });
    } catch (error) {
      if (mounted) _updateWorkspace(() => _error = _friendly(error));
    }
  }

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
        if ('${app?['review_note'] ?? ''}'.trim().isNotEmpty)
          _message('${app?['review_note']}'),
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
    Uint8List? frontPreview, backPreview;
    final selected = <String, String>{};
    final accountEmail = FirebaseAuth.instance.currentUser?.email?.trim() ?? '';
    final needsMobile = accountEmail.length > 40;
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
        required: false,
        dial: true,
      ),
      _FieldSpec(
        'mobile',
        'Mobile number',
        required: needsMobile,
        keyboardType: TextInputType.phone,
        helperText: needsMobile ? 'Required because the account email is too long for PhotonPay.' : 'Optional when your account email is accepted.',
      ),
      const _FieldSpec('residentialAddress', 'Street address', required: true),
      const _FieldSpec('residentialCity', 'City', required: true),
      const _FieldSpec('residentialState', 'State / province', required: true),
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
        helperText: 'Choose a type to show its required photo fields.',
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
    var submitting = false;
    var pickingFront = false;
    var pickingBack = false;
    Future<void> chooseIdPhoto({
      required bool isFront,
      required BuildContext dialogContext,
      required StateSetter setDialog,
    }) async {
      final source = await showModalBottomSheet<ImageSource>(
        context: dialogContext,
        useSafeArea: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isFront ? 'Add the front photo' : 'Add the back photo',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.camera_alt_outlined),
                  ),
                  title: const Text('Take a photo'),
                  subtitle: const Text('Open your camera'),
                  onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
                ),
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.photo_library_outlined),
                  ),
                  title: const Text('Choose from photos'),
                  subtitle: const Text('Select an existing JPG or PNG'),
                  onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
                ),
              ],
            ),
          ),
        ),
      );
      if (source == null || !dialogContext.mounted) return;
      setDialog(() {
        if (isFront) {
          pickingFront = true;
        } else {
          pickingBack = true;
        }
        photoWarning = null;
      });
      try {
        final photo = await imagePicker.pickImage(
          source: source,
          imageQuality: 80,
        );
        if (photo != null && dialogContext.mounted) {
          final preview = await photo.readAsBytes();
          if (!dialogContext.mounted) return;
          setDialog(() {
            if (isFront) {
              front = photo;
              frontPreview = preview;
            } else {
              back = photo;
              backPreview = preview;
            }
          });
        }
      } catch (_) {
        if (dialogContext.mounted) {
          setDialog(() => photoWarning = 'Could not open the selected source. Check its permission and try again.');
        }
      } finally {
        if (dialogContext.mounted) {
          setDialog(() {
            pickingFront = false;
            pickingBack = false;
          });
        }
      }
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Verify your identity'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Form(
                autovalidateMode: AutovalidateMode.disabled,
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
                    if (controllers['certType']!.text.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                            onPressed: submitting || pickingFront || pickingBack
                                ? null
                                : () => chooseIdPhoto(
                                    isFront: true,
                                    dialogContext: dialogContext,
                                    setDialog: setDialog,
                                  ),
                            icon: pickingFront
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.image),
                            label: Text(
                              front == null
                                  ? controllers['certType']!.text == 'passport'
                                        ? 'Passport photo page'
                                        : 'Front of ID'
                                  : 'Front selected',
                            ),
                            ),
                          ),
                          if (front != null)
                            _verificationPhotoPreview(
                              frontPreview,
                              controllers['certType']!.text == 'passport'
                                  ? 'Passport photo page'
                                  : 'Front of ID',
                              () => setDialog(() {
                                front = null;
                                frontPreview = null;
                              }),
                            ),
                          if (controllers['certType']!.text != 'passport')
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                              onPressed: submitting || pickingFront || pickingBack
                                  ? null
                                  : () => chooseIdPhoto(
                                      isFront: false,
                                      dialogContext: dialogContext,
                                      setDialog: setDialog,
                                    ),
                              icon: pickingBack
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.image),
                              label: Text(
                                back == null ? 'Back of ID' : 'Back selected',
                              ),
                              ),
                            ),
                          if (controllers['certType']!.text != 'passport' &&
                              back != null)
                            _verificationPhotoPreview(
                              backPreview,
                              'Back of ID',
                              () => setDialog(() {
                                back = null;
                                backPreview = null;
                              }),
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
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: submitting ? null : () => Navigator.pop(dialogContext),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                          onPressed: submitting
                              ? null
                              : () async {
                                  if (!key.currentState!.validate()) return;
                                  final mobileDigits = controllers['mobilePrefix']!.text
                                      .replaceAll(RegExp(r'[^0-9]'), '');
                                  final phone = controllers['mobile']!.text.replaceAll(
                                    RegExp(r'\D'),
                                    '',
                                  );
                                  if (phone.isNotEmpty &&
                                      !RegExp(r'^\d{1,4}$').hasMatch(mobileDigits)) {
                                    setDialog(
                                      () => photoWarning = 'Choose a valid country calling code, such as +971.',
                                    );
                                    return;
                                  }
                                  if (needsMobile && phone.isEmpty) {
                                    setDialog(() => photoWarning = 'Add a mobile number because your login email is longer than PhotonPay allows.');
                                    return;
                                  }
                                  if (phone.isNotEmpty && phone.length > 11) {
                                    setDialog(() => photoWarning = 'Mobile number may have at most 11 digits.');
                                    return;
                                  }
                                  if (front == null ||
                                      (controllers['certType']!.text != 'passport' &&
                                          back == null)) {
                                    setDialog(
                                      () => photoWarning = 'Choose the required ID photos.',
                                    );
                                    return;
                                  }
                                  for (final photo in [front, back].whereType<XFile>()) {
                                    final mime = (photo.mimeType ?? '').toLowerCase();
                                    final name = photo.name.toLowerCase();
                                    final isJpeg = mime == 'image/jpeg' || name.endsWith('.jpg') || name.endsWith('.jpeg');
                                    final isPng = mime == 'image/png' || name.endsWith('.png');
                                    if (!isJpeg && !isPng) {
                                      setDialog(() => photoWarning = 'Use a JPG or PNG ID photo.');
                                      return;
                                    }
                                    if (await photo.length() > 6 * 1024 * 1024) {
                                      setDialog(() => photoWarning = 'Each ID photo must be 6 MB or smaller. Choose a smaller photo.');
                                      return;
                                    }
                                  }
                                  setDialog(() {
                                    submitting = true;
                                    photoWarning = 'Uploading privately…';
                                  });
                                  try {
                                    final token = await _token();
                                    final frontData = base64Encode(
                                      await front!.readAsBytes(),
                                    );
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
                                    selected['mobilePrefix'] = mobileDigits.isEmpty
                                        ? ''
                                        : '+$mobileDigits';
                                    selected['mobile'] = phone;
                                    final result = await BackendApi.photonPayAction(
                                      token,
                                      'submit_registration',
                                      payload: {
                                        ...selected,
                                        'frontPhotoToken': frontResult['photo_token'],
                                        'backPhotoToken': backResult['photo_token'] ?? '',
                                      },
                                    );
                                    if (result['error'] != null)
                                      throw Exception(result['error']);
                                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                                    if (mounted)
                                      _updateWorkspace(() {
                                        _notice = 'Verification submitted for review.';
                                        _reloadSection();
                                      });
                                  } catch (error) {
                                    setDialog(() {
                                      submitting = false;
                                      photoWarning = _friendly(error);
                                    });
                                  }
                                },
                          child: Semantics(
                            label: submitting ? 'Submitting verification' : 'Submit verification',
                            child: submitting
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Submit'),
                          ),
                        ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

        ),
      ),
    );
    await _waitForDialogExitAnimation();
    for (final c in controllers.values) {
      c.dispose();
    }
  }

  Widget _verificationPhotoPreview(
    Uint8List? bytes,
    String label,
    VoidCallback onRemove,
  ) =>
      Container(
        width: double.infinity,
        height: 200,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFFF2F3F7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD9DDE7)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (bytes != null)
              Image.memory(bytes, fit: BoxFit.contain)
            else
              const Center(child: Icon(Icons.image_outlined, size: 36)),
            Positioned(
              left: 8,
              bottom: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    label,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton.filledTonal(
                tooltip: 'Remove $label',
                visualDensity: VisualDensity.compact,
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            ),
          ],
        ),
      );
}
