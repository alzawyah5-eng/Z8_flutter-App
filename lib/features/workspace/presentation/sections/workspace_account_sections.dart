part of '../../workspace_page.dart';

extension _WorkspaceAccountSections on _WorkspacePageState {
  Widget _assistant(
    List<Map<String, dynamic>> conversations,
    String agent,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionHeader(
        agent == 'technical_support' ? 'Technical support' : 'Card assistant',
        'Ask about cards, account status or operational issues.',
      ),
      _actionButton('Start a conversation', Icons.chat, () async {
        final conv = await BackendApi.createAssistantConversation(
          await _token(),
          agent,
        );
        if (mounted)
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AssistantConversationPage(
                conversation: conv,
                agent: agent,
                sections: _sections,
                onLogout: _confirmLogout,
                onNavigate: (section) {
                  Navigator.pop(context);
                  _navigateTo(section);
                },
              ),
            ),
          );
        if (mounted) _updateWorkspace(() => _reloadSection());
      }),
      for (final item in conversations.where(
        (conversation) => (conversation['messages'] as List? ?? []).any(
          (message) =>
              message is Map && '${message['content'] ?? ''}'.trim().isNotEmpty,
        ),
      ))
        Card(
          child: ListTile(
            title: Text(_conversationTitle(item, agent)),
            subtitle: Text(
              '${(item['messages'] as List? ?? []).length} messages',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AssistantConversationPage(
                    conversation: item,
                    agent: agent,
                    sections: _sections,
                    onLogout: _confirmLogout,
                    onNavigate: (section) {
                      Navigator.pop(context);
                      _navigateTo(section);
                    },
                  ),
                ),
              );
              if (mounted) _updateWorkspace(() => _reloadSection());
            },
          ),
        ),
    ],
  );

  String _conversationTitle(Map<String, dynamic> conversation, String agent) {
    final metadata = conversation['metadata'];
    if (metadata is Map) {
      for (final key in const ['title', 'name']) {
        final value = metadata[key]?.toString().trim();
        if (value != null && value.isNotEmpty && value != 'null') return value;
      }
    }
    return agent == 'technical_support'
        ? 'Technical support'
        : 'Card assistant';
  }

  Future<void> _deleteAccount() async {
    final confirmation = await _ask(
      'Permanently delete account · type your email',
      initial: '',
    );
    if (confirmation == null ||
        confirmation.trim().toLowerCase() != _email.toLowerCase()) {
      if (confirmation != null && mounted)
        _updateWorkspace(
          () => _error = 'The email did not match this signed-in account.',
        );
      return;
    }
    try {
      final response = await BackendApi.deleteAccount(
        await _token(),
        confirmation,
      );
      if (response['error'] != null) throw Exception(response['error']);
      await _logout();
    } catch (error) {
      if (mounted) _updateWorkspace(() => _error = _friendly(error));
    }
  }

  Widget _account() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionHeader('Account', 'Profile and security settings.'),
      _statusCard('Signed in as', _email),
      _statusCard('Role', _admin ? 'Administrator' : 'User'),
      const Card(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'Account closure disables sign-in and keeps financial activity for programme audit. A minimal email record is retained to prevent recreating the closed account.',
          ),
        ),
      ),
      _actionButton('Sign out', Icons.logout, _confirmLogout),
      _actionButton(
        'Permanently delete account',
        Icons.delete_forever,
        _deleteAccount,
      ),
    ],
  );
}
