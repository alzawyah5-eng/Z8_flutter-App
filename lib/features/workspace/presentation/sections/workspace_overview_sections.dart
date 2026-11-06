part of '../../workspace_page.dart';

extension _WorkspaceOverviewSections on _WorkspacePageState {
  int get _bottomIndex {
    if (_admin)
      return switch (_section) {
        'cards' => 1,
        'clients' => 2,
        'funds' => 3,
        _ => 0,
      };
    return switch (_section) {
      'cards' => 1,
      'activity' => 2,
      'account' => 3,
      _ => 0,
    };
  }

  IconData _icon(String key) => switch (key) {
    'home' => Icons.space_dashboard_rounded,
    'cards' => Icons.credit_card_rounded,
    'clients' => Icons.groups_2_rounded,
    'funds' || 'wallet' => Icons.account_balance_wallet_rounded,
    'activity' => Icons.receipt_long_rounded,
    'verification' => Icons.verified_user_rounded,
    'connection' => Icons.account_tree_rounded,
    'assistant' || 'support' => Icons.support_agent_rounded,
    'notifications' => Icons.notifications_active_rounded,
    _ => Icons.account_circle_rounded,
  };

  Widget _sectionBody(dynamic data) {
    final children = <Widget>[const SizedBox(height: 12)];
    if (_notice != null) children.add(_message(_notice!));
    if (_error != null) children.add(_message(_error!, error: true));
    switch (_section) {
      case 'home':
        final map = Map<String, dynamic>.from(data as Map);
        children.add(
          _sectionHeader(
            _admin ? 'Admin workspace' : 'Welcome back',
            _admin
                ? 'Manage cardholders, cards and client balances.'
                : 'Your cards, account balance and recent activity.',
          ),
        );
        if (_admin) {
          children.add(
            _statRow(
              'Cards',
              '${map['cards'].length}',
              'Clients',
              '${map['holders'].length}',
            ),
          );
          children.add(
            _statRow(
              'Requests awaiting approval',
              '${map['requests'].length}',
              'Latest activity',
              '${map['transactions'].length} records',
            ),
          );
          if ((map['requests'] as List).isNotEmpty)
            children.add(_requestCards(map['requests']));
          children.add(
            _actionButton(
              'Create virtual card',
              Icons.add_card,
              () => _issueCard(map['holders']),
            ),
          );
          children.add(
            _actionButton(
              'Sync cardholders from PhotonPay',
              Icons.sync,
              () async => _call('sync_holders', {'pageIndex': 1}),
            ),
          );
        } else {
          final wallet = Map<String, dynamic>.from(map['wallet'] as Map);
          final verification = Map<String, dynamic>.from(
            map['verification'] as Map,
          );
          children.add(
            _statRow(
              'Available balance',
              'USD ' + (wallet['available'] ?? 0).toString(),
              'Cards',
              '${map['cards'].length}',
            ),
          );
          children.add(
            _statusCard(
              'Verification',
              verification['identity']?['status'] ??
                  verification['application']?['status'] ??
                  'Not started',
            ),
          );
          children.add(
            _actionButton(
              'Request a card',
              Icons.add_card_rounded,
              () => _requestCard(verification),
            ),
          );
          children.add(
            _actionButton('Report a deposit', Icons.add, _reportDeposit),
          );
        }
        children.add(_recordList('Recent transactions', map['transactions']));
        children.add(_cardGrid(_items(map['cards'])));
        break;
      case 'cards':
        final map = Map<String, dynamic>.from(data as Map);
        children.add(_cardsSection(map));
        break;
      case 'activity':
        children.add(_activitySection(Map<String, dynamic>.from(data as Map)));
        break;
      case 'verification':
        children.add(_verification(Map<String, dynamic>.from(data as Map)));
        break;
      case 'wallet':
        children.add(_wallet(Map<String, dynamic>.from(data as Map)));
        break;
      case 'clients':
        children.add(_clients(Map<String, dynamic>.from(data as Map)));
        break;
      case 'funds':
        children.add(_funds(Map<String, dynamic>.from(data as Map)));
        break;
      case 'connection':
        children.add(_connection(Map<String, dynamic>.from(data as Map)));
        break;
      case 'notifications':
        children.add(
          _sectionHeader(
            'Notifications',
            'Updates about your verification, funds and cards.',
          ),
        );
        children.add(const PushTestCard());
        final notificationItems = _items(data);
        if (notificationItems.any((item) => item['read'] != true)) {
          children.add(
            _actionButton(
              'Mark all as read',
              Icons.done_all_rounded,
              () => _markAllNotificationsRead(notificationItems),
            ),
          );
        }
        children.add(_notificationList(notificationItems));
        break;
      case 'assistant':
      case 'support':
        children.add(
          _assistant(
            _items(data),
            _section == 'support'
                ? 'technical_support'
                : _admin
                ? 'card_setup_assistant'
                : 'cardholder_assistant',
          ),
        );
        break;
      case 'account':
        children.add(_account());
        break;
      default:
        children.add(_message('This section is not available.'));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: children,
    );
  }

  Widget _notificationList(List<Map<String, dynamic>> items) => Card(
    child: Column(
      children: [
        if (items.isEmpty) const ListTile(title: Text('No notifications yet.')),
        for (final item in items)
          ListTile(
            leading: Icon(
              item['read'] == true
                  ? Icons.notifications_none
                  : Icons.notifications_active_outlined,
            ),
            title: Text('${item['title'] ?? 'Z8 update'}'),
            subtitle: Text(
              '${item['body'] ?? ''}\n${item['created_date'] ?? ''}',
            ),
            isThreeLine: true,
            onTap: () async {
              if (item['read'] != true) {
                await BackendApi.updateEntity(
                  await _token(),
                  'Notification',
                  '${item['id']}',
                  {
                    'read': true,
                    'read_at': DateTime.now().toUtc().toIso8601String(),
                  },
                );
              }
              final section = _sectionForNotification('${item['link'] ?? ''}');
              if (mounted)
                _updateWorkspace(() {
                  if (section != null) _navigationCubit.openSection(section);
                  _navigationCubit.refresh();
                });
            },
          ),
      ],
    ),
  );

  Future<void> _markAllNotificationsRead(
    List<Map<String, dynamic>> items,
  ) async {
    final pending = items.where((item) => item['read'] != true).toList();
    final token = await _token();
    await Future.wait(
      pending.map(
        (item) => BackendApi.updateEntity(
          token,
          'Notification',
          '${item['id']}',
          {'read': true, 'read_at': DateTime.now().toUtc().toIso8601String()},
        ),
      ),
    );
    if (mounted) _updateWorkspace(() => _navigationCubit.refresh());
  }

  String? _sectionForNotification(String link) {
    final path = Uri.tryParse(link)?.path ?? link;
    if (path.startsWith('/cards')) return 'cards';
    if (path.startsWith('/activity')) return 'activity';
    if (path.startsWith('/verification')) return 'verification';
    if (path.startsWith('/account')) return 'account';
    if (path.startsWith('/admin/funds')) return _admin ? 'funds' : 'wallet';
    if (path.startsWith('/cardholders')) return _admin ? 'clients' : null;
    return null;
  }

  Widget _cardsSection(Map<String, dynamic> data) => StatefulBuilder(
    builder: (context, setLocal) {
      final cards = _items(data['cards']);
      final query = _cardSearch.trim().toLowerCase();
      final visible = cards.where((card) {
        final status = '${card['status'] ?? ''}'.toLowerCase();
        final matchesStatus =
            _cardStatusFilter == 'all' || status == _cardStatusFilter;
        final haystack =
            '${card['nickname'] ?? ''} ${card['owner_email'] ?? ''} ${card['cardholder_name'] ?? ''}'
                .toLowerCase();
        return matchesStatus && (query.isEmpty || haystack.contains(query));
      }).toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            _admin ? 'Card management' : 'Your cards',
            _admin
                ? 'Issue and manage clients’ virtual cards.'
                : 'Review balances, payment controls and card details.',
          ),
          if (_admin)
            _actionButton('Issue card', Icons.add_card_rounded, () async {
              final holders = _items(
                await BackendApi.queryEntity(
                  await _token(),
                  'Cardholder',
                  limit: 100,
                ),
              );
              await _issueCard(holders);
            }),
          if (!_admin) ...[
            _statusCard(
              'Available account balance',
              'USD ${Map<String, dynamic>.from(data['wallet'] as Map)['available'] ?? 0}',
            ),
            _actionButton(
              'Request a card',
              Icons.add_card_rounded,
              () => _requestCard(
                Map<String, dynamic>.from(data['registration'] as Map),
              ),
            ),
            _actionButton('Add funds', Icons.savings_rounded, _reportDeposit),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 2,
            children: [
              for (final status in [
                'all',
                'active',
                'frozen',
                'pending',
                'cancelled',
              ])
                ChoiceChip(
                  label: Text(
                    status == 'all'
                        ? 'All cards'
                        : '${status[0].toUpperCase()}${status.substring(1)}',
                  ),
                  selected: _cardStatusFilter == status,
                  onSelected: (_) => setLocal(() => _cardStatusFilter = status),
                  selectedColor: const Color(0xFFF7EEF3),
                  labelStyle: TextStyle(
                    color: _cardStatusFilter == status
                        ? const Color(0xFF74144F)
                        : const Color(0xFF68758A),
                    fontWeight: FontWeight.w700,
                  ),
                  side: BorderSide(
                    color: _cardStatusFilter == status
                        ? const Color(0xFFD9B7CA)
                        : const Color(0xFFE5E2E7),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 9),
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Search cards, clients or email',
            ),
            onChanged: (value) => setLocal(() => _cardSearch = value),
          ),
          const SizedBox(height: 8),
          if (_admin && (data['requests'] as List? ?? []).isNotEmpty)
            _requestCards(data['requests']),
          _cardGrid(visible),
          if (cards.isNotEmpty && visible.isEmpty)
            _emptyState(
              Icons.search_off_rounded,
              'No cards match these filters',
              'Clear the search or choose another card status.',
            ),
        ],
      );
    },
  );

  Widget _activitySection(Map<String, dynamic> page) {
    var items = _items(page);
    var cursor = page['next_cursor'] as String?;
    var hasMore = page['has_more'] == true;
    var loadingMore = false;
    return StatefulBuilder(
      builder: (context, setLocal) {
        final query = _activitySearch.trim().toLowerCase();
        final visible = items.where((item) {
          final kind = '${item['kind'] ?? ''}'.toLowerCase();
          final matchesKind =
              _activityKindFilter == 'all' || kind == _activityKindFilter;
          final text =
              '${item['merchant'] ?? ''} ${item['event'] ?? ''} ${item['card_nickname'] ?? ''}'
                  .toLowerCase();
          return matchesKind && (query.isEmpty || text.contains(query));
        }).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(
              'Activity, at a glance',
              _admin
                  ? 'Payments, refunds and card updates across your workspace.'
                  : 'A clear view of payments, refunds and updates on your cards.',
            ),
            Wrap(
              spacing: 7,
              runSpacing: 2,
              children: [
                for (final pair in const [
                  ('all', 'All activity'),
                  ('spend', 'Payments'),
                  ('refund', 'Refunds'),
                  ('event', 'Card updates'),
                ])
                  ChoiceChip(
                    label: Text(pair.$2),
                    selected: _activityKindFilter == pair.$1,
                    onSelected: (_) =>
                        setLocal(() => _activityKindFilter = pair.$1),
                    selectedColor: const Color(0xFFF7EEF3),
                    labelStyle: TextStyle(
                      color: _activityKindFilter == pair.$1
                          ? const Color(0xFF74144F)
                          : const Color(0xFF68758A),
                      fontWeight: FontWeight.w700,
                    ),
                    side: BorderSide(
                      color: _activityKindFilter == pair.$1
                          ? const Color(0xFFD9B7CA)
                          : const Color(0xFFE5E2E7),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 9),
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search merchant or card',
              ),
              onChanged: (value) => setLocal(() {
                _activitySearch = value.trim().toLowerCase();
              }),
            ),
            const SizedBox(height: 8),
            if (visible.isEmpty)
              _emptyState(
                Icons.receipt_long_rounded,
                'No activity in this view',
                'Try a different type or search term.',
              )
            else
              _recordList('Transactions · ${visible.length}', visible),
            if (hasMore && _activityKindFilter == 'all' && query.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: OutlinedButton.icon(
                  onPressed: loadingMore
                      ? null
                      : () async {
                          setLocal(() => loadingMore = true);
                          try {
                            final next = await BackendApi.queryEntity(
                              await _token(),
                              'CardTransaction',
                              // Non-admin ownership is enforced server-side.
                              filter: const {},
                              sort: '-occurred_at',
                              limit: 30,
                              cursor: cursor,
                            );
                            setLocal(() {
                              items = [...items, ..._items(next)];
                              cursor = next['next_cursor'] as String?;
                              hasMore = next['has_more'] == true;
                              loadingMore = false;
                            });
                          } catch (_) {
                            setLocal(() => loadingMore = false);
                            if (mounted)
                              _updateWorkspace(
                                () => _error = 'Could not load more activity. Please retry.',
                              );
                          }
                        },
                  icon: loadingMore
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.expand_more_rounded),
                  label: Text(
                    loadingMore ? 'Loading activity…' : 'Show more activity',
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _emptyState(IconData icon, String title, String detail) => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Icon(icon, size: 30, color: const Color(0xFFB88A3B)),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF14263D),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF68758A), fontSize: 12),
          ),
        ],
      ),
    ),
  );

  Widget _cardGrid(List<Map<String, dynamic>> cards) {
    if (cards.isEmpty)
      return _emptyState(
        Icons.credit_card_rounded,
        'Your cards will appear here',
        'Cards and their current status stay together in this space.',
      );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 13, 2, 5),
          child: Text(
            'YOUR CARDS  ·  ${cards.length}',
            style: const TextStyle(
              color: Color(0xFF68758A),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ),
        for (final card in cards)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(13),
                onTap: () => _cardActions(card),
                child: Ink(
                  height: 190,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _cardGradient(card),
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x24302435),
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -34,
                        top: -56,
                        child: Container(
                          width: 185,
                          height: 185,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: .10),
                              width: 24,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 24,
                        bottom: -90,
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: .055),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: .15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Z8',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 9),
                                const Expanded(
                                  child: Text(
                                    'Z8 PORTAL',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.6,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.contactless_rounded,
                                  color: Colors.white.withValues(alpha: .85),
                                  size: 23,
                                ),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              '••••  ••••  ••••  ${card['last4'] ?? '••••'}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                letterSpacing: 2,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 13),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${card['cardholder_name'] ?? card['owner_email'] ?? 'CARDHOLDER'}'
                                            .toUpperCase(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: .78,
                                          ),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${card['nickname'] ?? 'Virtual card'}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: .14),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: .25,
                                      ),
                                    ),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    '${card['status'] ?? 'pending'}'
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: .7,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
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

  List<Color> _cardGradient(Map<String, dynamic> card) {
    final tier = '${card['tier'] ?? ''}'.toLowerCase();
    if (tier == 'emerald') return const [Color(0xFF116B4B), Color(0xFF0C392E)];
    if (tier == 'crimson') return const [Color(0xFF8F2638), Color(0xFF431C34)];
    if ('${card['status']}'.toLowerCase() == 'frozen')
      return const [Color(0xFF576477), Color(0xFF263447)];
    return const [Color(0xFF6E174E), Color(0xFF25243D)];
  }

  Widget _sectionHeader(String title, String subtitle) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 8, bottom: 14),
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF14263D), Color(0xFF52203F)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(9),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1C35122E),
          blurRadius: 16,
          offset: Offset(0, 7),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 22, height: 2, color: const Color(0xFFD5AD67)),
            const SizedBox(width: 8),
            Text(
              _admin ? 'ADMIN WORKSPACE' : 'Z8 PORTAL',
              style: const TextStyle(
                color: Color(0xFFF1D9A9),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFFE5D7E0),
            fontSize: 13,
            height: 1.45,
          ),
        ),
      ],
    ),
  );
  Widget _message(String text, {bool error = false}) => Card(
    color: error
        ? Theme.of(context).colorScheme.errorContainer
        : Theme.of(context).colorScheme.secondaryContainer,
    child: Padding(padding: const EdgeInsets.all(12), child: Text(text)),
  );
  Widget _statRow(String a, String av, String b, String bv) => Row(
    children: [
      Expanded(child: _statusCard(a, av)),
      const SizedBox(width: 8),
      Expanded(child: _statusCard(b, bv)),
    ],
  );
  Widget _statusCard(String title, String value) {
    final label = title.toLowerCase();
    final accent = label.contains('balance') || label.contains('fund')
        ? const Color(0xFF167653)
        : label.contains('pending') || label.contains('request')
        ? const Color(0xFFB88A3B)
        : const Color(0xFF74144F);
    return Card(
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(9),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 13, 12, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF7B7180),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .8,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontSize: 17),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(String label, IconData icon, VoidCallback action) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xFFE5E2E7)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: action,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color:
                          icon == Icons.savings_rounded ||
                              icon == Icons.account_balance_wallet_rounded
                          ? const Color(0xFFE8F2EC)
                          : icon == Icons.verified_user_rounded
                          ? const Color(0xFFFBF5E8)
                          : const Color(0xFFF7EEF3),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      icon,
                      color:
                          icon == Icons.savings_rounded ||
                              icon == Icons.account_balance_wallet_rounded
                          ? const Color(0xFF167653)
                          : icon == Icons.verified_user_rounded
                          ? const Color(0xFFB88A3B)
                          : const Color(0xFF74144F),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFF17243B),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Color(0xFF8B8490),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _recordList(
    String title,
    dynamic raw, {
    Future<void> Function(Map<String, dynamic>)? onTap,
  }) {
    final records = raw is List
        ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '$title · ${records.length}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (records.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text('Nothing to show yet.'),
            ),
          for (final item in records)
            ListTile(
              title: Text(_recordTitle(item)),
              subtitle: Text(
                _recordSubtitle(item),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: onTap == null ? null : const Icon(Icons.chevron_right),
              onTap: onTap == null ? null : () => onTap(item),
            ),
        ],
      ),
    );
  }

  String _recordTitle(Map<String, dynamic> item) =>
      '${item['nickname'] ?? item['full_name'] ?? item['client_name'] ?? item['merchant'] ?? item['title'] ?? item['event'] ?? item['kind'] ?? item['email'] ?? 'Record'}';
  String _recordSubtitle(Map<String, dynamic> item) => [
    item['status'],
    item['last4'] == null ? null : '•••• ${item['last4']}',
    item['amount'] == null
        ? null
        : '${item['amount']} ${item['currency'] ?? 'USD'}',
    item['occurred_at'] ?? item['created_date'],
  ].where((v) => v != null && '$v'.isNotEmpty).join(' · ');

  Widget _requestCards(List<dynamic> raw) => Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ListTile(title: Text('Card requests awaiting approval')),
        for (final value in raw.whereType<Map>())
          ListTile(
            title: Text(
              '${value['client_name'] ?? value['owner_email'] ?? 'Client'} · USD ${value['amount'] ?? 0}',
            ),
            subtitle: Text(
              '${value['tier'] ?? ''} · ${value['purpose'] ?? ''}',
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (choice) async {
                if (choice == 'approve') {
                  final country = await _ask(
                    'Your current country (2-letter code)',
                  );
                  if (country != null)
                    await _call('approve_card_request', {
                      'requestId': value['id'],
                      'gpsCountry': country.toUpperCase(),
                    });
                } else {
                  final note = await _ask('Reason for rejecting');
                  if (note != null && note.trim().length >= 3)
                    await _call('reject_card_request', {
                      'requestId': value['id'],
                      'note': note,
                    });
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'approve', child: Text('Approve & issue')),
                PopupMenuItem(value: 'reject', child: Text('Reject')),
              ],
            ),
          ),
      ],
    ),
  );
}
