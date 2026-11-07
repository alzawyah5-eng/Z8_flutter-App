part of '../../workspace_page.dart';

extension _WorkspaceClientAdminSections on _WorkspacePageState {
  Widget _wallet(Map<String, dynamic> data) {
    final wallet = Map<String, dynamic>.from(
      data['wallet'] as Map? ?? const {},
    );
    final registration = Map<String, dynamic>.from(
      data['registration'] as Map? ?? const {},
    );
    final requestState = Map<String, dynamic>.from(
      registration['card_request'] as Map? ?? const {},
    );
    final verified = requestState['verified'] == true;
    final ladder = (wallet['ladder'] as List? ?? const [])
        .whereType<Map>()
        .map((step) => Map<String, dynamic>.from(step))
        .toList();
    final nextTier = wallet['next_tier'] is Map
        ? Map<String, dynamic>.from(wallet['next_tier'] as Map)
        : null;
    final deposited = double.tryParse('${wallet['deposited'] ?? 0}') ?? 0;
    final currentTier = '${wallet['tier'] ?? ''}';
    final currentFloor =
        ladder
            .where((step) => '${step['id']}' == currentTier)
            .map((step) => double.tryParse('${step['from']}') ?? 0)
            .firstOrNull ??
        0;
    final nextFloor = double.tryParse('${nextTier?['from'] ?? 0}') ?? 0;
    final progress = nextTier == null
        ? 1.0
        : ((deposited - currentFloor) / (nextFloor - currentFloor))
              .clamp(0.0, 1.0)
              .toDouble();
    final applicationStatus = '${registration['application']?['status'] ?? ''}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          'Your account',
          'Money you deposited with us. New cards and top-ups are paid from it.',
        ),
        if (!verified) ...[
          _message(
            'Verify your identity first. After approval, you can add funds and request cards.',
          ),
          if (applicationStatus != 'submitted' &&
              applicationStatus != 'approved')
            _actionButton(
              applicationStatus == 'rejected'
                  ? 'Review my details'
                  : 'Verify now',
              Icons.verified_user_outlined,
              () => _navigateTo('verification'),
            ),
        ] else ...[
          _statRow(
            'Balance',
            'USD ${wallet['balance'] ?? 0}',
            'Set aside',
            'USD ${wallet['held'] ?? 0}',
          ),
          _statusCard('Available', 'USD ${wallet['available'] ?? 0}'),
          if ((double.tryParse('${wallet['held'] ?? 0}') ?? 0) > 0)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Set aside: reserved for your card request until it is approved.',
                style: TextStyle(color: Color(0xFF68758A), fontSize: 12),
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${wallet['tier_name'] ?? 'No card tier yet'} tier',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'You have deposited USD ${wallet['deposited'] ?? 0} in total.',
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 4),
                  Text(
                    nextTier == null
                        ? 'You have reached the highest available tier.'
                        : 'Deposit USD ${nextTier['remaining']} more to unlock ${nextTier['name']}.',
                  ),
                ],
              ),
            ),
          ),
          if ('${wallet['funding_instructions'] ?? ''}'.isNotEmpty)
            _message('${wallet['funding_instructions']}'),
          _actionButton('Add funds', Icons.add, _reportDeposit),
          _recordList(
            'Movements',
            wallet['entries'],
            onTap: (entry) async {
              if (entry['has_proof'] == true)
                await _viewDepositProof('${entry['id']}', admin: false);
            },
          ),
        ],
      ],
    );
  }

  Widget _clients(Map<String, dynamic> data) {
    final applications = data['applications'] as List? ?? [];
    final users = data['users'] as List? ?? [];
    final holders = _items(data['holders']);
    final holderEmails = holders
        .expand((holder) => [holder['email'], holder['owner_email']])
        .whereType<String>()
        .map((email) => email.toLowerCase())
        .toSet();
    final appByEmail = {
      for (final app in applications.whereType<Map>())
        '${app['owner_email'] ?? app['email'] ?? ''}'.toLowerCase(): app,
    };
    final signedUp = users.where((user) {
      if (user is! Map || user['role'] == 'admin') return false;
      final email = '${user['email'] ?? ''}'.toLowerCase();
      final appStatus = appByEmail[email]?['status'];
      return email.isNotEmpty &&
          !holderEmails.contains(email) &&
          (appStatus == null || appStatus == 'rejected');
    }).toList();
    var signedQuery = '';
    return StatefulBuilder(
      builder: (context, setLocal) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Cardholders', 'Sync, register and review clients.'),
          _actionButton(
            'Sync clients from PhotonPay',
            Icons.sync,
            () async => _call('sync_holders', {'pageIndex': 1}),
          ),
          _actionButton(
            'Add cardholder',
            Icons.person_add_alt_1,
            _addCardholder,
          ),
          _actionButton(
            'Record deposit or balance adjustment',
            Icons.account_balance_wallet_outlined,
            () => _recordClientFunds(_items(users)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            children: [
              for (final tab in const [
                ('card-users', 'Card users'),
                ('applications', 'Applications'),
                ('signed-up', 'Signed up'),
              ])
                ChoiceChip(
                  label: Text(
                    '${tab.$2} · ${tab.$1 == 'card-users'
                        ? holders.length
                        : tab.$1 == 'applications'
                        ? applications.where((a) => a is Map && a['status'] == 'submitted').length
                        : signedUp.length}',
                  ),
                  selected: _clientTab == tab.$1,
                  onSelected: (_) => setLocal(() => _clientTab = tab.$1),
                  selectedColor: const Color(0xFFF7EEF3),
                  labelStyle: TextStyle(
                    color: _clientTab == tab.$1
                        ? const Color(0xFF74144F)
                        : const Color(0xFF68758A),
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
            ],
          ),
          if (_clientTab == 'applications')
            Card(
              child: Column(
                children: [
                  const ListTile(title: Text('Verification applications')),
                  if (!applications.any(
                    (raw) => raw is Map && raw['status'] == 'submitted',
                  ))
                    const ListTile(
                      title: Text('No applications awaiting review.'),
                    ),
                  for (final raw in applications)
                    if (raw is Map && raw['status'] == 'submitted')
                      ListTile(
                        title: Text(
                          (raw['first_name'] ?? '').toString() +
                              ' ' +
                              (raw['last_name'] ?? '').toString(),
                        ),
                        subtitle: Text(
                          (raw['owner_email'] ?? '').toString() +
                              ' · ' +
                              (raw['cert_type'] ?? '').toString(),
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (action) async {
                            if (action == 'front' || action == 'back') {
                              await _viewApplicationPhoto(
                                '${raw['id']}',
                                action,
                              );
                            } else if (action == 'approve') {
                              await _call('approve_application', {
                                'applicationId': raw['id'],
                              });
                            } else {
                              final note = await _ask('Reason for rejection');
                              if (note != null)
                                await _call('reject_application', {
                                  'applicationId': raw['id'],
                                  'note': note,
                                });
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'front',
                              child: Text('View front / passport photo'),
                            ),
                            if ('${raw['back_file_uri'] ?? ''}'.isNotEmpty)
                              const PopupMenuItem(
                                value: 'back',
                                child: Text('View back photo'),
                              ),
                            const PopupMenuItem(
                              value: 'approve',
                              child: Text('Approve & send'),
                            ),
                            const PopupMenuItem(
                              value: 'reject',
                              child: Text('Reject'),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          if (_clientTab == 'card-users')
            _holderRecords(holders, _items(data['cards'])),
          if (_clientTab == 'signed-up') ...[
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search account name or email',
              ),
              onChanged: (value) =>
                  setLocal(() => signedQuery = value.trim().toLowerCase()),
            ),
            _recordList(
              'Signed up, not verified',
              signedUp
                  .where(
                    (user) =>
                        '${user['full_name'] ?? ''} ${user['email'] ?? ''}'
                            .toLowerCase()
                            .contains(signedQuery),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _holderRecords(
    List<Map<String, dynamic>> holders,
    List<Map<String, dynamic>> cards,
  ) {
    var query = '';
    var statusFilter = 'all';
    var reviewFilter = 'all';
    var actionOnly = false;
    DateTime? createdFrom;
    DateTime? createdTo;
    return StatefulBuilder(
      builder: (context, setLocal) {
        final shown =
            holders.where((holder) {
              final providerStatus = '${holder['provider_status'] ?? ''}'
                  .toLowerCase();
              final reviewStatus = '${holder['review_status'] ?? ''}'
                  .toLowerCase();
              final needsAction =
                  const [
                    'modify',
                    'cert_required',
                    'rejected',
                  ].contains(reviewStatus) ||
                  const ['failed', 'disabled'].contains(providerStatus);
              final date = DateTime.tryParse(
                '${holder['photon_created_at'] ?? holder['created_date'] ?? ''}',
              );
              if (statusFilter != 'all' && providerStatus != statusFilter)
                return false;
              if (reviewFilter != 'all' && reviewStatus != reviewFilter)
                return false;
              if (actionOnly && !needsAction) return false;
              if (createdFrom != null &&
                  date != null &&
                  date.isBefore(
                    DateTime(
                      createdFrom!.year,
                      createdFrom!.month,
                      createdFrom!.day,
                    ),
                  ))
                return false;
              if (createdTo != null &&
                  date != null &&
                  date.isAfter(
                    DateTime(
                      createdTo!.year,
                      createdTo!.month,
                      createdTo!.day,
                      23,
                      59,
                      59,
                    ),
                  ))
                return false;
              return '${holder['photon_cardholder_id'] ?? ''} ${holder['full_name'] ?? ''} ${holder['email'] ?? ''} ${holder['owner_email'] ?? ''} ${holder['phone'] ?? ''} ${holder['nationality'] ?? ''}'
                  .toLowerCase()
                  .contains(query);
            }).toList()..sort(
              (a, b) => '${b['photon_created_at'] ?? b['created_date'] ?? ''}'
                  .compareTo(
                    '${a['photon_created_at'] ?? a['created_date'] ?? ''}',
                  ),
            );
        Future<void> chooseDate(bool from) async {
          final selected = await showDatePicker(
            context: context,
            initialDate: (from ? createdFrom : createdTo) ?? DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime.now().add(const Duration(days: 1)),
          );
          if (selected != null)
            setLocal(() {
              if (from) {
                createdFrom = selected;
              } else {
                createdTo = selected;
              }
            });
        }

        Future<void> showCsv() async {
          String cell(dynamic value) => '"${'$value'.replaceAll('"', '""')}"';
          final rows = <List<dynamic>>[
            const [
              'Card user ID',
              'First name',
              'Last name',
              'Email',
              'Mobile',
              'Nationality',
              'Status',
              'Review status',
              'Reason',
              'Created',
              'Z8 account',
              'Cards',
            ],
            for (final holder in shown)
              [
                holder['photon_cardholder_id'],
                holder['first_name'],
                holder['last_name'],
                holder['email'],
                holder['phone'],
                holder['nationality'],
                holder['provider_status'],
                holder['review_status'],
                holder['review_reason'],
                holder['photon_created_at'],
                holder['owner_email'],
                cards
                    .where(
                      (card) =>
                          '${card['cardholder_id'] ?? ''}' ==
                              '${holder['id']}' ||
                          ('${holder['photon_cardholder_id'] ?? ''}'
                                  .isNotEmpty &&
                              '${card['photon_cardholder_id'] ?? ''}' ==
                                  '${holder['photon_cardholder_id']}'),
                    )
                    .length,
              ],
          ];
          final csv = rows.map((row) => row.map(cell).join(',')).join('\n');
          await showDialog<void>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Export card users'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(child: SelectableText(csv)),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Close'),
                ),
                FilledButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: csv));
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                    if (mounted)
                      _updateWorkspace(
                        () => _notice = 'Filtered cardholder CSV copied. Paste it into a spreadsheet to save it.',
                      );
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copy CSV'),
                ),
              ],
            ),
          );
        }

        final filtersActive =
            query.isNotEmpty ||
            statusFilter != 'all' ||
            reviewFilter != 'all' ||
            actionOnly ||
            createdFrom != null ||
            createdTo != null;
        return Card(
          child: Column(
            children: [
              const ListTile(title: Text('Registered cardholders')),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Search name, email or review status',
                  ),
                  onChanged: (value) =>
                      setLocal(() => query = value.trim().toLowerCase()),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    DropdownButton<String>(
                      value: statusFilter,
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('All statuses'),
                        ),
                        DropdownMenuItem(
                          value: 'normal',
                          child: Text('Normal'),
                        ),
                        DropdownMenuItem(
                          value: 'pending',
                          child: Text('Under review'),
                        ),
                        DropdownMenuItem(
                          value: 'disabled',
                          child: Text('Disabled'),
                        ),
                        DropdownMenuItem(
                          value: 'failed',
                          child: Text('Failed'),
                        ),
                      ],
                      onChanged: (value) =>
                          setLocal(() => statusFilter = value ?? 'all'),
                    ),
                    DropdownButton<String>(
                      value: reviewFilter,
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('All review statuses'),
                        ),
                        DropdownMenuItem(
                          value: 'pending',
                          child: Text('Under review'),
                        ),
                        DropdownMenuItem(
                          value: 'modify',
                          child: Text('Pending modification'),
                        ),
                        DropdownMenuItem(
                          value: 'approved',
                          child: Text('Approved'),
                        ),
                        DropdownMenuItem(
                          value: 'rejected',
                          child: Text('Rejected'),
                        ),
                        DropdownMenuItem(
                          value: 'cert_required',
                          child: Text('Identity required'),
                        ),
                      ],
                      onChanged: (value) =>
                          setLocal(() => reviewFilter = value ?? 'all'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => chooseDate(true),
                      icon: const Icon(Icons.calendar_today_outlined, size: 16),
                      label: Text(
                        createdFrom == null
                            ? 'Created from'
                            : '${createdFrom!.year}-${createdFrom!.month.toString().padLeft(2, '0')}-${createdFrom!.day.toString().padLeft(2, '0')}',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => chooseDate(false),
                      icon: const Icon(Icons.event_outlined, size: 16),
                      label: Text(
                        createdTo == null
                            ? 'Created to'
                            : '${createdTo!.year}-${createdTo!.month.toString().padLeft(2, '0')}-${createdTo!.day.toString().padLeft(2, '0')}',
                      ),
                    ),
                    FilterChip(
                      label: Text(
                        'Needs action · ${holders.where((holder) => const ['modify', 'cert_required', 'rejected'].contains('${holder['review_status']}') || const ['failed', 'disabled'].contains('${holder['provider_status']}')).length}',
                      ),
                      selected: actionOnly,
                      onSelected: (value) => setLocal(() => actionOnly = value),
                    ),
                    if (filtersActive)
                      TextButton(
                        onPressed: () => setLocal(() {
                          query = '';
                          statusFilter = 'all';
                          reviewFilter = 'all';
                          actionOnly = false;
                          createdFrom = null;
                          createdTo = null;
                        }),
                        child: const Text('Clear filters'),
                      ),
                    OutlinedButton.icon(
                      onPressed: shown.isEmpty ? null : showCsv,
                      icon: const Icon(Icons.download_outlined, size: 16),
                      label: const Text('Export CSV'),
                    ),
                    Text('${shown.length} of ${holders.length} card users'),
                  ],
                ),
              ),
              if (shown.isEmpty)
                ListTile(
                  title: Text(
                    holders.isEmpty
                        ? 'No cardholders yet.'
                        : 'No cardholders match this search.',
                  ),
                ),
              for (final holder in shown)
                ListTile(
                  title: Text(
                    '${holder['full_name'] ?? 'Cardholder'} · ${cards.where((card) => '${card['cardholder_id'] ?? ''}' == '${holder['id']}' || '${card['owner_email'] ?? ''}'.toLowerCase() == '${holder['owner_email'] ?? holder['email'] ?? ''}'.toLowerCase()).length} cards',
                  ),
                  subtitle: Text(
                    '${holder['email'] ?? ''} · ${holder['status'] ?? ''} · ${holder['review_status'] ?? ''}',
                  ),
                  trailing: IconButton(
                    tooltip: 'Edit at PhotonPay',
                    icon: const Icon(
                      Icons.edit_rounded,
                      color: Color(0xFFB88A3B),
                    ),
                    onPressed: () => _editCardholder(holder),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editCardholder(Map<String, dynamic> holder) => _formDialog(
    'Edit PhotonPay cardholder',
    const [
      _FieldSpec('firstName', 'First name'),
      _FieldSpec('lastName', 'Last name'),
      _FieldSpec('dateOfBirth', 'Date of birth', date: true),
      _FieldSpec('nationalityCountryCode', 'Nationality', country: true),
      _FieldSpec('email', 'Email'),
      _FieldSpec('mobilePrefix', 'Country calling code', dial: true),
      _FieldSpec('mobile', 'Mobile number'),
      _FieldSpec('residentialAddress', 'Street address'),
      _FieldSpec('residentialCity', 'City'),
      _FieldSpec('residentialState', 'State / province'),
      _FieldSpec('residentialPostalCode', 'Postal code'),
      _FieldSpec('residentialCountryCode', 'Residence country', country: true),
      _FieldSpec(
        'certType',
        'ID document type',
        options: const [
          _FieldOption('passport', 'Passport'),
          _FieldOption('id_card', 'National ID card'),
          _FieldOption('resident_permit', 'Residence permit'),
        ],
      ),
      _FieldSpec('certId', 'New ID number (optional)'),
      _FieldSpec('certCountryCode', 'ID issuing country', country: true),
    ],
    (values) async {
      final payload = <String, Object?>{'cardholderRecordId': holder['id']};
      for (final e in values.entries) {
        if (e.value.trim().isNotEmpty) payload[e.key] = e.value;
      }
      final result = await BackendApi.photonPayAction(
        await _token(),
        'edit_holder',
        payload: payload,
      );
      if (result['error'] != null) throw Exception(result['error']);
      if (mounted)
        _updateWorkspace(() {
          _notice = 'Cardholder updated at PhotonPay.';
          _reloadSection();
        });
    },
    initialValues: {
      'firstName': holder['first_name'],
      'lastName': holder['last_name'],
      'dateOfBirth': holder['date_of_birth'],
      'nationalityCountryCode': holder['nationality'],
      'email': holder['email'],
      'mobile': (holder['phone'] ?? '').toString().split(' ').skip(1).join(' '),
      'mobilePrefix': (holder['phone'] ?? '')
          .toString()
          .split(' ')
          .first
          .replaceAll(RegExp(r'[^0-9]'), ''),
      'residentialAddress': holder['address_line'],
      'residentialCity': holder['city'],
      'residentialState': holder['state'],
      'residentialPostalCode': holder['postal_code'],
      'residentialCountryCode': holder['country'],
      'certType': holder['cert_type'],
      'certCountryCode': holder['cert_country'],
    },
  );

  Future<void> _viewApplicationPhoto(String id, String side) async {
    try {
      final response = await BackendApi.photonPayAction(
        await _token(),
        'application_photo',
        payload: {'applicationId': id, 'side': side},
      );
      if (response['error'] != null) throw Exception(response['error']);
      final url = response['url']?.toString() ?? '';
      if (url.isEmpty) throw Exception('The ID photo is unavailable.');
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('ID photo · ${side == 'front' ? 'front' : 'back'}'),
          content: SizedBox(
            width: 480,
            child: Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  const Text('Could not load the private ID photo.'),
            ),
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
  }

  Widget _funds(Map<String, dynamic> data) {
    final pending = data['pending_deposits'] as List? ?? [];
    var search = '';
    return StatefulBuilder(
      builder: (context, setLocal) {
        final clients = _items(data['clients']);
        final filteredClients = clients
            .where(
              (client) =>
                  '${client['name'] ?? client['full_name'] ?? ''} ${client['email'] ?? ''}'
                      .toLowerCase()
                      .contains(search.toLowerCase()),
            )
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(
              'Client funds',
              'Review reported deposits and client balances.',
            ),
            _statRow(
              'Pending deposits',
              (data['totals']?['pending_count'] ?? pending.length).toString(),
              'Clients',
              ((data['clients'] as List? ?? []).length).toString(),
            ),
            _actionButton(
              'Record funds / correct a balance',
              Icons.edit_note,
              () => _recordClientFunds(_items(data['clients'])),
            ),
            Card(
              child: Column(
                children: [
                  const ListTile(title: Text('Deposits awaiting review')),
                  if (pending.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline_rounded, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text('No deposits need review right now.'),
                          ),
                        ],
                      ),
                    ),
                  for (final raw in pending)
                    if (raw is Map)
                      ListTile(
                        title: Text(
                          (raw['client_name'] ?? raw['owner_email'] ?? 'Client')
                                  .toString() +
                              ' · USD ' +
                              (raw['amount'] ?? '').toString(),
                        ),
                        subtitle: Text(
                          (raw['method'] ?? '').toString() +
                              ' · ' +
                              (raw['reference'] ?? '').toString(),
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (choice) async {
                            if (choice == 'proof') {
                              await _viewDepositProof('${raw['id']}');
                              return;
                            }
                            if (choice == 'confirm') {
                              final amountText = await _ask(
                                'Amount actually received (USD)',
                                initial: '${raw['amount'] ?? ''}',
                              );
                              final actualAmount = num.tryParse(
                                amountText ?? '',
                              );
                              if (actualAmount == null || actualAmount <= 0) {
                                if (amountText != null && mounted)
                                  _updateWorkspace(
                                    () => _error =
                                        'Enter the amount actually received.',
                                  );
                                return;
                              }
                              await _call('wallet_review', {
                                'entryId': raw['id'],
                                'decision': 'confirm',
                                'amount': actualAmount,
                              });
                            }
                            if (choice == 'reject') {
                              final note = await _ask('Reason for rejection');
                              if (note != null)
                                await _call('wallet_review', {
                                  'entryId': raw['id'],
                                  'decision': 'reject',
                                  'note': note,
                                });
                            }
                          },
                          itemBuilder: (_) => [
                            if (raw['has_proof'] == true)
                              const PopupMenuItem(
                                value: 'proof',
                                child: Text('View payment proof'),
                              ),
                            PopupMenuItem(
                              value: 'confirm',
                              child: Text('Confirm received'),
                            ),
                            PopupMenuItem(
                              value: 'reject',
                              child: Text('Reject'),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search clients by name or email',
              ),
              onChanged: (value) => setLocal(() => search = value.trim()),
            ),
            _recordList(
              'Client balances',
              filteredClients,
              onTap: _openClientLedger,
            ),
          ],
        );
      },
    );
  }

  Future<void> _openClientLedger(Map<String, dynamic> client) async {
    final email = '${client['email'] ?? client['owner_email'] ?? ''}';
    if (email.isEmpty) return;
    try {
      final ledger = await BackendApi.photonPayAction(
        await _token(),
        'wallet_client',
        payload: {'ownerEmail': email},
      );
      if (ledger['error'] != null) throw Exception(ledger['error']);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('${client['name'] ?? client['full_name'] ?? email}'),
          content: SizedBox(
            width: 520,
            height: MediaQuery.sizeOf(context).height * .62,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(email, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _statusCard(
                        'Balance',
                        'USD ${ledger['balance'] ?? 0}',
                      ),
                    ),
                    Expanded(
                      child: _statusCard('Held', 'USD ${ledger['held'] ?? 0}'),
                    ),
                    Expanded(
                      child: _statusCard(
                        'Available',
                        'USD ${ledger['available'] ?? 0}',
                      ),
                    ),
                  ],
                ),
                if (ledger['tier'] != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Tier: ${ledger['tier']} · Deposited USD ${ledger['deposited'] ?? 0}',
                    ),
                  ),
                const Divider(),
                const Text(
                  'Account movements',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: ListView(
                    children: [
                      for (final entry
                          in (ledger['entries'] as List? ?? [])
                              .whereType<Map>())
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${entry['kind'] ?? 'Movement'} · USD ${entry['amount'] ?? 0}',
                          ),
                          subtitle: Text(
                            [
                                  entry['status'],
                                  formatZ8DateTime(entry['date']) == '—'
                                      ? null
                                      : formatZ8DateTime(entry['date']),
                                  entry['note'],
                                ]
                                .where(
                                  (value) =>
                                      value != null && '$value'.isNotEmpty,
                                )
                                .join(' · '),
                          ),
                          trailing: entry['has_proof'] == true
                              ? IconButton(
                                  tooltip: 'View payment proof',
                                  icon: const Icon(
                                    Icons.receipt_long_rounded,
                                    color: Color(0xFFB88A3B),
                                  ),
                                  onPressed: () =>
                                      _viewDepositProof('${entry['id']}'),
                                )
                              : null,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                _recordClientCorrection(email);
              },
              icon: const Icon(Icons.tune_rounded),
              label: const Text('Correct balance'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) _updateWorkspace(() => _error = _friendly(error));
    }
  }

  Future<void> _recordClientCorrection(String email) => _formDialog(
    'Correct client balance',
    const [
      _FieldSpec(
        'amount',
        'Amount (USD) · positive adds, negative takes away',
        required: true,
        keyboardType: TextInputType.number,
      ),
      _FieldSpec(
        'note',
        'Reason shown to client',
        required: true,
        multiline: true,
      ),
      _FieldSpec('adminNote', 'Internal note (optional)', multiline: true),
    ],
    (values) async {
      final amount = num.tryParse(values['amount'] ?? '');
      if (amount == null || amount == 0)
        throw Exception('Enter a valid non-zero amount.');
      final result = await BackendApi.photonPayAction(
        await _token(),
        'wallet_record',
        payload: {
          'ownerEmail': email,
          'kind': 'adjustment',
          'amount': amount,
          'note': values['note'],
          'adminNote': values['adminNote'],
        },
      );
      if (result['error'] != null) throw Exception(result['error']);
      if (mounted)
        _updateWorkspace(() {
          _notice = 'Client balance correction saved.';
          _reloadSection();
        });
    },
  );

  Future<void> _viewDepositProof(String entryId, {bool admin = true}) async {
    try {
      final result = await BackendApi.photonPayAction(
        await _token(),
        admin ? 'deposit_proof' : 'my_deposit_proof',
        payload: {'entryId': entryId},
      );
      if (result['error'] != null) throw Exception(result['error']);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('${result['name'] ?? 'Payment proof'}'),
          content: SizedBox(
            width: 500,
            child: Image.network(
              '${result['url']}',
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  const Text('Could not load the private payment proof.'),
            ),
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
  }

  Widget _connection(Map<String, dynamic> data) {
    final status = Map<String, dynamic>.from(data['status'] as Map? ?? {});
    final diag = Map<String, dynamic>.from(data['diagnostics'] as Map? ?? {});
    final probes = diag['probes'] as List? ?? [];
    final settings = Map<String, dynamic>.from(data['settings'] as Map? ?? {});
    final balance = Map<String, dynamic>.from(data['balance'] as Map? ?? {});
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          'Connection & API',
          'PhotonPay credentials stay on the backend.',
        ),
        _statusCard(
          'PhotonPay',
          status['connected'] == true ? 'Linked' : 'Not linked',
        ),
        _statusCard(
          'Environment',
          '${status['env'] ?? diag['environment'] ?? 'unknown'}',
        ),
        _statusCard(
          'Main account',
          '${status['master_account_email'] ?? 'Not configured'}',
        ),
        _statusCard(
          'PhotonPay USD balance',
          balance['balance']?.toString() ?? 'Not loaded',
        ),
        _actionButton(
          'Refresh PhotonPay balance',
          Icons.account_balance,
          () async {
            await _call('balance');
            if (mounted) _updateWorkspace(() => _reloadSection());
          },
        ),
        _actionButton(
          'Programme defaults',
          Icons.tune,
          () => _editProgrammeSettings(settings),
        ),
        _actionButton('Re-test connection', Icons.refresh, () async {
          await _call('status');
          _updateWorkspace(() => _reloadSection());
        }),
        _actionButton(
          'Run full diagnostic check',
          Icons.health_and_safety_outlined,
          () => _updateWorkspace(() {
            _notice = 'Diagnostics refreshed';
            _reloadSection();
          }),
        ),
        Card(
          child: Column(
            children: [
              const ListTile(title: Text('Provider probes')),
              for (final p in probes.whereType<Map>())
                ListTile(
                  title: Text('${p['environment']} · ${p['auth_mode']}'),
                  subtitle: Text(
                    '${p['message'] ?? p['network_error'] ?? (p['success'] == true ? 'Passed' : 'Failed')} · ${p['code'] ?? ''}',
                  ),
                ),
            ],
          ),
        ),
        _message(
          'Use the backend .env for API credentials and signing keys. This screen never displays their values.',
        ),
      ],
    );
  }

  Future<void> _editProgrammeSettings(
    Map<String, dynamic> current,
  ) => _formDialog(
    'Programme defaults',
    [
      _FieldSpec(
        'client_requests_enabled',
        'Verified clients can request a card',
        required: true,
        options: const [
          _FieldOption('true', 'Enabled'),
          _FieldOption('false', 'Disabled'),
        ],
      ),
      _FieldSpec(
        'client_topups_enabled',
        'Clients can add card credit from their balance',
        required: true,
        options: const [
          _FieldOption('true', 'Enabled'),
          _FieldOption('false', 'Disabled'),
        ],
      ),
      _FieldSpec(
        'max_cards_per_client',
        'Maximum cards per client',
        required: true,
      ),
      const _FieldSpec('default_max_on_daily', 'Default daily limit USD'),
      const _FieldSpec('default_max_on_monthly', 'Default monthly limit USD'),
      const _FieldSpec(
        'default_max_on_percent',
        'Default per-payment limit USD',
      ),
      _FieldSpec(
        'tier_emerald_enabled',
        'Offer Emerald',
        required: true,
        options: const [
          _FieldOption('true', 'Enabled'),
          _FieldOption('false', 'Disabled'),
        ],
      ),
      _FieldSpec(
        'tier_plum_enabled',
        'Offer Plum',
        required: true,
        options: const [
          _FieldOption('true', 'Enabled'),
          _FieldOption('false', 'Disabled'),
        ],
      ),
      _FieldSpec(
        'tier_crimson_enabled',
        'Offer Crimson',
        required: true,
        options: const [
          _FieldOption('true', 'Enabled'),
          _FieldOption('false', 'Disabled'),
        ],
      ),
      _FieldSpec(
        'tier_start_amount',
        'Emerald starts at (USD deposited)',
        required: true,
      ),
      _FieldSpec(
        'tier_plum_from',
        'Plum starts at (USD deposited)',
        required: true,
      ),
      _FieldSpec(
        'tier_crimson_from',
        'Crimson starts at (USD deposited)',
        required: true,
      ),
      _FieldSpec(
        'min_opening_amount',
        'Minimum card opening USD',
        required: true,
      ),
      const _FieldSpec('funding_instructions', 'Client funding instructions'),
    ],
    (values) async {
      bool flag(String key) {
        final value = values[key]?.toLowerCase();
        if (value != 'true' && value != 'false')
          throw Exception('$key must be true or false.');
        return value == 'true';
      }

      final data = <String, Object?>{
        'client_requests_enabled': flag('client_requests_enabled'),
        'client_topups_enabled': flag('client_topups_enabled'),
        'tier_emerald_enabled': flag('tier_emerald_enabled'),
        'tier_plum_enabled': flag('tier_plum_enabled'),
        'tier_crimson_enabled': flag('tier_crimson_enabled'),
        'funding_instructions': values['funding_instructions'] ?? '',
      };
      for (final key in [
        'max_cards_per_client',
        'default_max_on_daily',
        'default_max_on_monthly',
        'default_max_on_percent',
        'tier_start_amount',
        'tier_plum_from',
        'tier_crimson_from',
        'min_opening_amount',
      ]) {
        final value = values[key] ?? '';
        if (value.isEmpty && key.startsWith('default_')) {
          data[key] = null;
          continue;
        }
        final n = num.tryParse(value);
        if (n == null || n < 0)
          throw Exception('Enter a valid non-negative value for $key.');
        data[key] = n;
      }
      final token = await _token();
      final response = current['id'] == null
          ? await BackendApi.createEntity(token, 'ProgrammeSettings', data)
          : await BackendApi.updateEntity(
              token,
              'ProgrammeSettings',
              '${current['id']}',
              data,
            );
      if (response['error'] != null) throw Exception(response['error']);
      if (mounted)
        _updateWorkspace(() {
          _notice = 'Programme defaults saved.';
          _reloadSection();
        });
    },
    initialValues: {
      for (final field in [
        'client_requests_enabled',
        'client_topups_enabled',
        'max_cards_per_client',
        'default_max_on_daily',
        'default_max_on_monthly',
        'default_max_on_percent',
        'tier_emerald_enabled',
        'tier_plum_enabled',
        'tier_crimson_enabled',
        'tier_start_amount',
        'tier_plum_from',
        'tier_crimson_from',
        'min_opening_amount',
        'funding_instructions',
      ])
        field: current[field] ?? (field.endsWith('_enabled') ? true : ''),
    },
  );
}
