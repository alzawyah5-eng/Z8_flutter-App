import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/backend_api.dart';
import '../../../core/notifications/notification_service.dart';
import 'country_options.dart';
import 'presentation/bloc/workspace_navigation_cubit.dart';
import 'presentation/widgets/request_card_dialog.dart';
import 'presentation/widgets/push_test_card.dart';
import 'presentation/widgets/workspace_bottom_bar.dart';
part 'presentation/sections/workspace_overview_sections.dart';
part 'presentation/sections/workspace_card_verification_sections.dart';
part 'presentation/sections/workspace_client_admin_sections.dart';
part 'presentation/sections/workspace_account_sections.dart';

/// Role-aware mobile workspace backed by the same PostgreSQL/API operations as
/// the web app. Authorization remains enforced by the backend on every call.
class WorkspacePage extends StatefulWidget {
  const WorkspacePage({super.key});

  @override
  State<WorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends State<WorkspacePage> {
  late final WorkspaceNavigationCubit _navigationCubit;
  Map<String, dynamic>? _profile;
  String get _section => _navigationCubit.state.section;
  String? _error;
  String? _notice;
  bool _loading = true;
  int get _revision => _navigationCubit.state.revision;
  String _cardStatusFilter = 'all';
  String _cardSearch = '';
  String _activityKindFilter = 'all';
  String _activitySearch = '';
  String _clientTab = 'card-users';

  bool get _admin => _profile?['role'] == 'admin';
  String get _email => '${_profile?['email'] ?? ''}';

  static const _userSections = <String, String>{
    'home': 'Overview',
    'cards': 'Cards',
    'activity': 'Activity',
    'verification': 'Verification',
    'wallet': 'Account funds',
    'assistant': 'Card assistant',
    'notifications': 'Notifications',
    'account': 'Account',
  };
  static const _adminSections = <String, String>{
    'home': 'Overview',
    'cards': 'Cards',
    'clients': 'Cardholders',
    'funds': 'Client funds',
    'activity': 'Activity',
    'connection': 'Connection & API',
    'assistant': 'Card assistant',
    'support': 'Technical support',
    'notifications': 'Notifications',
    'account': 'Account',
  };

  Map<String, String> get _sections => _admin ? _adminSections : _userSections;

  @override
  void initState() {
    super.initState();
    _navigationCubit = WorkspaceNavigationCubit();
    _loadProfile();
  }

  @override
  void dispose() {
    _navigationCubit.close();
    super.dispose();
  }

  Future<String> _token() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null)
      throw const BackendApiException(
        'session_expired',
        'Please sign in again.',
      );
    // Firebase reuses a valid cached ID token and silently refreshes it with
    // its persisted refresh token when needed.
    return (await user.getIdToken()) ??
        (throw const BackendApiException(
          'session_expired',
          'Please sign in again.',
        ));
  }

  Future<void> _loadProfile() async {
    try {
      final data = await BackendApi.getMe(await _token());
      if (!mounted) return;
      setState(() {
        _profile = data;
        _loading = false;
      });
      unawaitedRegisterPush();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendly(error);
      });
    }
  }

  void unawaitedRegisterPush() {
    unawaited(NotificationService.registerForCurrentUser());
  }

  void _updateWorkspace(VoidCallback update) {
    if (mounted) setState(update);
  }

  Future<dynamic> _loadSection() async {
    final token = await _token();
    switch (_section) {
      case 'home':
        final cards = await BackendApi.queryEntity(
          token,
          'Card',
          filter: {'form_factor': 'virtual_card'},
          limit: 10,
          sort: '-created_date',
        );
        final tx = await BackendApi.queryEntity(
          token,
          'CardTransaction',
          limit: 8,
          sort: '-occurred_at',
        );
        if (!_admin) {
          final wallet = await BackendApi.photonPayAction(token, 'my_wallet');
          final verification = await BackendApi.photonPayAction(
            token,
            'my_registration',
          );
          return {
            'cards': _items(cards),
            'transactions': _items(tx),
            'wallet': wallet,
            'verification': verification,
          };
        }
        final holders = await BackendApi.queryEntity(
          token,
          'Cardholder',
          limit: 10,
          sort: '-created_date',
        );
        final requests = await BackendApi.queryEntity(
          token,
          'CardRequest',
          filter: {'status': 'pending'},
          limit: 20,
          sort: '-created_date',
        );
        return {
          'cards': _items(cards),
          'transactions': _items(tx),
          'holders': _items(holders),
          'requests': _items(requests),
        };
      case 'cards':
        final cards = await BackendApi.queryEntity(
          token,
          'Card',
          filter: {'form_factor': 'virtual_card'},
          limit: 100,
          sort: '-created_date',
        );
        final requests = _admin
            ? await BackendApi.queryEntity(
                token,
                'CardRequest',
                filter: {'status': 'pending'},
                limit: 50,
                sort: '-created_date',
              )
            : <String, dynamic>{};
        final wallet = !_admin
            ? await BackendApi.photonPayAction(token, 'my_wallet')
            : <String, dynamic>{};
        final registration = !_admin
            ? await BackendApi.photonPayAction(token, 'my_registration')
            : <String, dynamic>{};
        return {
          'cards': _items(cards),
          'requests': _items(requests),
          'wallet': wallet,
          'registration': registration,
        };
      case 'activity':
        return await BackendApi.queryEntity(
          token,
          'CardTransaction',
          // The API scopes non-admin transaction reads to the authenticated
          // account using its protected owner-email hash. Filtering by the
          // plaintext owner_email field is intentionally rejected.
          filter: const {},
          limit: 30,
          sort: '-occurred_at',
        );
      case 'verification':
        return await BackendApi.photonPayAction(token, 'my_registration');
      case 'wallet':
        return await BackendApi.photonPayAction(token, 'my_wallet');
      case 'clients':
        final values = await Future.wait([
          BackendApi.queryEntity(
            token,
            'Cardholder',
            limit: 200,
            sort: '-created_date',
          ),
          BackendApi.queryEntity(
            token,
            'CardholderApplication',
            limit: 200,
            sort: '-created_date',
          ),
          BackendApi.queryEntity(token, 'User', limit: 500),
          BackendApi.queryEntity(
            token,
            'Card',
            limit: 500,
            sort: '-created_date',
          ),
        ]);
        return {
          'holders': _items(values[0]),
          'applications': _items(values[1]),
          'users': _items(values[2]),
          'cards': _items(values[3]),
        };
      case 'funds':
        return await BackendApi.photonPayAction(token, 'wallet_overview');
      case 'connection':
        final results = await Future.wait([
          BackendApi.photonPayAction(token, 'status'),
          BackendApi.photonPayDiagnostics(token),
          BackendApi.photonPayAction(token, 'balance'),
          BackendApi.queryEntity(token, 'ProgrammeSettings', limit: 1),
        ]);
        return {
          'status': results[0],
          'diagnostics': results[1],
          'balance': results[2],
          'settings': _items(results[3]).firstOrNull ?? <String, dynamic>{},
        };
      case 'notifications':
        return _items(
          await BackendApi.queryEntity(
            token,
            'Notification',
            limit: 100,
            sort: '-created_date',
          ),
        );
      case 'assistant':
      case 'support':
        final agent = _admin
            ? (_section == 'support'
                  ? 'technical_support'
                  : 'card_setup_assistant')
            : 'cardholder_assistant';
        return _items(await BackendApi.assistantConversations(token, agent));
      default:
        return _profile ?? {};
    }
  }

  List<Map<String, dynamic>> _items(dynamic result) {
    final list = result is List
        ? result
        : result is Map
        ? result['items']
        : null;
    if (list is! List) return [];
    return list
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  String _friendly(Object error) => error is BackendApiException
      ? error.message
      : error.toString().replaceFirst('Exception: ', '');

  Future<void> _refresh() async {
    setState(() {
      _error = null;
      _navigationCubit.refresh();
    });
    await _loadProfile();
  }

  Future<void> _call(
    String action, [
    Map<String, Object?> payload = const {},
  ]) async {
    if (mounted) setState(() => _error = null);
    try {
      final result = await BackendApi.photonPayAction(
        await _token(),
        action,
        payload: payload,
      );
      if (result['error'] != null) throw Exception(result['error']);
      if (!mounted) return;
      setState(() {
        _notice = 'Done';
        _error = null;
        _navigationCubit.refresh();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _friendly(error));
    }
  }

  Future<void> _formDialog(
    String title,
    List<_FieldSpec> fields,
    Future<void> Function(Map<String, String>) onSubmit, {
    Map<String, dynamic> initialValues = const {},
  }) async {
    final controllers = {
      for (final field in fields)
        field.key: TextEditingController(
          text: '${initialValues[field.key] ?? ''}',
        ),
    };
    final formKey = GlobalKey<FormState>();
    var busy = false;
    String? dialogError;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final field in fields)
                    if (field.visibleWhenKey == null ||
                        controllers[field.visibleWhenKey]?.text ==
                            field.visibleWhenValue)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: field.staticValue != null
                            ? InputDecorator(
                                decoration: InputDecoration(
                                  labelText: field.label,
                                  helperText: field.helperText,
                                ),
                                child: Text(field.staticValue!),
                              )
                            : field.country || field.dial
                            ? FormField<String>(
                                initialValue:
                                    controllers[field.key]!.text.isEmpty
                                    ? null
                                    : controllers[field.key]!.text,
                                validator: field.required
                                    ? (value) => (value ?? '').isEmpty
                                          ? 'Choose a country'
                                          : null
                                    : null,
                                builder: (state) => InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () async {
                                    final country = await _chooseCountry(
                                      controllers[field.key]!.text,
                                    );
                                    if (country == null) return;
                                    final value = field.country
                                        ? country.code
                                        : country.dial;
                                    setDialog(
                                      () =>
                                          controllers[field.key]!.text = value,
                                    );
                                    state.didChange(value);
                                  },
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText: field.label,
                                      helperText: field.helperText,
                                      errorText: state.errorText,
                                      suffixIcon: const Icon(Icons.expand_more),
                                    ),
                                    child: Text(
                                      field.country
                                          ? (z8Countries
                                                    .where(
                                                      (c) =>
                                                          c.code ==
                                                          controllers[field
                                                                  .key]!
                                                              .text,
                                                    )
                                                    .firstOrNull
                                                    ?.name ??
                                                'Choose country')
                                          : (controllers[field.key]!
                                                    .text
                                                    .isEmpty
                                                ? 'Choose country code'
                                                : '+${controllers[field.key]!.text}'),
                                    ),
                                  ),
                                ),
                              )
                            : field.options != null
                            ? DropdownButtonFormField<String>(
                                initialValue:
                                    field.options!.any(
                                      (option) =>
                                          option.value ==
                                          controllers[field.key]!.text,
                                    )
                                    ? controllers[field.key]!.text
                                    : null,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: field.label,
                                  helperText: field.helperText,
                                ),
                                items: [
                                  for (final option in field.options!)
                                    DropdownMenuItem(
                                      value: option.value,
                                      child: Text(
                                        option.label,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    final option = field.options!.firstWhere(
                                      (item) => item.value == value,
                                    );
                                    setDialog(() {
                                      controllers[field.key]!.text = value;
                                      for (final update
                                          in option.updates.entries) {
                                        controllers[update.key]?.text =
                                            update.value;
                                      }
                                    });
                                  }
                                },
                                validator: field.required
                                    ? (value) => (value ?? '').isEmpty
                                          ? 'Choose an option'
                                          : null
                                    : null,
                              )
                            : field.date
                            ? TextFormField(
                                controller: controllers[field.key],
                                readOnly: true,
                                decoration: InputDecoration(
                                  labelText: field.label,
                                  helperText: field.helperText,
                                  suffixIcon: const Icon(
                                    Icons.calendar_today_outlined,
                                  ),
                                ),
                                onTap: () async {
                                  final now = DateTime.now();
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime(now.year - 25),
                                    firstDate: DateTime(1900),
                                    lastDate: now,
                                  );
                                  if (picked != null) {
                                    controllers[field.key]!.text =
                                        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                                  }
                                },
                                validator: field.required
                                    ? (value) => (value ?? '').trim().isEmpty
                                          ? 'Choose a date'
                                          : null
                                    : null,
                              )
                            : TextFormField(
                                controller: controllers[field.key],
                                keyboardType: field.keyboardType,
                                maxLines: field.multiline ? 3 : 1,
                                minLines: field.multiline ? 2 : 1,
                                textCapitalization:
                                    field.key.toLowerCase().contains('email')
                                    ? TextCapitalization.none
                                    : TextCapitalization.sentences,
                                autocorrect: !field.key.toLowerCase().contains(
                                  'email',
                                ),
                                decoration: InputDecoration(
                                  labelText: field.label,
                                  helperText: field.helperText,
                                ),
                                validator: field.required
                                    ? (value) => (value ?? '').trim().isEmpty
                                          ? 'This field is required'
                                          : null
                                    : null,
                              ),
                      ),
                  if (dialogError != null)
                    Text(
                      dialogError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialog(() => busy = true);
                      try {
                        await onSubmit({
                          for (final entry in controllers.entries)
                            entry.key: entry.value.text.trim(),
                        });
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      } catch (error) {
                        setDialog(() {
                          busy = false;
                          dialogError = _friendly(error);
                        });
                      }
                    },
              child: Text(busy ? 'Saving…' : 'Save'),
            ),
          ],
        ),
      ),
    );
    await _waitForDialogExitAnimation();
    for (final controller in controllers.values) {
      controller.dispose();
    }
  }

  Future<Z8Country?> _chooseCountry(String selectedCode) async {
    final search = TextEditingController();
    final result = await showDialog<Z8Country>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) {
          final query = search.text.trim().toLowerCase();
          final matches = z8Countries
              .where(
                (country) =>
                    country.name.toLowerCase().contains(query) ||
                    country.code.toLowerCase().contains(query) ||
                    country.dial.contains(query.replaceAll('+', '')),
              )
              .toList();
          return AlertDialog(
            title: const Text('Choose country'),
            content: SizedBox(
              width: 420,
              height: 480,
              child: Column(
                children: [
                  TextField(
                    controller: search,
                    autofocus: true,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search name or code',
                    ),
                    onChanged: (_) => setDialog(() {}),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (context, index) {
                        final country = matches[index];
                        return ListTile(
                          dense: true,
                          selected: country.code == selectedCode,
                          title: Text(country.name),
                          trailing: Text(
                            '+${country.dial}  ·  ${country.code}',
                          ),
                          onTap: () => Navigator.pop(dialogContext, country),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    await _waitForDialogExitAnimation();
    search.dispose();
    return result;
  }

  /// showDialog completes as soon as the route starts popping. Keep any
  /// controllers used by its TextFields alive until the reverse transition and
  /// the frame that removes those fields have both completed.
  Future<void> _waitForDialogExitAnimation() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await WidgetsBinding.instance.endOfFrame;
  }

  Widget _styledFormField(
    _FieldSpec field,
    TextEditingController controller,
    StateSetter setDialog,
  ) {
    String? requiredValue(String? value) =>
        field.required && (value ?? '').trim().isEmpty
        ? 'This field is required'
        : null;
    if (field.country || field.dial) {
      return FormField<String>(
        initialValue: controller.text.isEmpty ? null : controller.text,
        validator: requiredValue,
        builder: (state) => InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            final country = await _chooseCountry(controller.text);
            if (country == null) return;
            final value = field.country ? country.code : country.dial;
            setDialog(() => controller.text = value);
            state.didChange(value);
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: field.label,
              helperText: field.helperText,
              errorText: state.errorText,
              suffixIcon: const Icon(Icons.expand_more),
            ),
            child: Text(
              field.country
                  ? (z8Countries
                            .where((item) => item.code == controller.text)
                            .firstOrNull
                            ?.name ??
                        'Choose country')
                  : (controller.text.isEmpty
                        ? 'Choose country code'
                        : '+${controller.text}'),
            ),
          ),
        ),
      );
    }
    if (field.options != null) {
      return DropdownButtonFormField<String>(
        initialValue:
            field.options!.any((option) => option.value == controller.text)
            ? controller.text
            : null,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: field.label,
          helperText: field.helperText,
        ),
        items: [
          for (final option in field.options!)
            DropdownMenuItem(
              value: option.value,
              child: Text(option.label, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (value) {
          if (value != null) setDialog(() => controller.text = value);
        },
        validator: field.required
            ? (value) => (value ?? '').isEmpty ? 'Choose an option' : null
            : null,
      );
    }
    if (field.date) {
      return TextFormField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(
          labelText: field.label,
          helperText: field.helperText,
          suffixIcon: const Icon(Icons.calendar_today_outlined),
        ),
        onTap: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: DateTime(now.year - 25),
            firstDate: DateTime(1900),
            lastDate: now,
          );
          if (picked != null)
            setDialog(
              () => controller.text =
                  '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}',
            );
        },
        validator: requiredValue,
      );
    }
    return TextFormField(
      controller: controller,
      keyboardType: field.keyboardType,
      maxLines: field.multiline ? 3 : 1,
      minLines: field.multiline ? 2 : 1,
      textCapitalization: field.key.toLowerCase().contains('email')
          ? TextCapitalization.none
          : TextCapitalization.sentences,
      autocorrect: !field.key.toLowerCase().contains('email'),
      decoration: InputDecoration(
        labelText: field.label,
        helperText: field.helperText,
      ),
      validator: requiredValue,
    );
  }

  Future<void> _requestCard([Map<String, dynamic>? registration]) async {
    Map<String, dynamic> state;
    try {
      state =
          registration ??
          await BackendApi.photonPayAction(await _token(), 'my_registration');
    } catch (error) {
      if (mounted) setState(() => _error = _friendly(error));
      return;
    }
    final request = Map<String, dynamic>.from(
      state['card_request'] as Map? ?? {},
    );
    if (request['can_request'] != true) {
      if (!mounted) return;
      setState(
        () => _error =
            '${request['reason'] ?? 'Card requests are not available right now.'}',
      );
      return;
    }
    if (!mounted) return;
    final completed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => RequestCardDialog(
        requestState: request,
        onSubmit: (payload) async {
          final response = await BackendApi.photonPayAction(
            await _token(),
            'request_card',
            payload: payload,
          );
          if (response['error'] != null) {
            throw Exception('${response['error']}');
          }
        },
      ),
    );
    if (completed == true && mounted) {
      setState(() {
        _notice = 'Card request sent for review.';
        _error = null;
        _navigationCubit.refresh();
      });
    }
  }

  Future<Map<String, String>?> _selectDepositProof() async {
    final attach = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment proof'),
        content: const Text('Attach a receipt or transfer confirmation?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Skip'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Choose image'),
          ),
        ],
      ),
    );
    if (attach != true) return null;
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return null;
    final result = await BackendApi.photonPayAction(
      await _token(),
      'store_deposit_proof',
      payload: {
        'dataBase64': base64Encode(await file.readAsBytes()),
        'fileName': file.name,
        'mimeType':
            file.mimeType ??
            (file.name.toLowerCase().endsWith('.png')
                ? 'image/png'
                : 'image/jpeg'),
      },
    );
    if (result['error'] != null) throw Exception(result['error']);
    return {'proofToken': '${result['proof_token']}', 'proofName': file.name};
  }

  Future<void> _reportDeposit() => _formDialog(
    'Report a deposit',
    [
      const _FieldSpec(
        'amount',
        'Amount in USD',
        required: true,
        keyboardType: TextInputType.number,
      ),
      const _FieldSpec(
        'method',
        'Paid by',
        required: true,
        options: [
          _FieldOption('bank_transfer', 'Bank transfer'),
          _FieldOption('cash', 'Cash'),
          _FieldOption('other', 'Other'),
        ],
      ),
      const _FieldSpec('reference', 'Payment reference'),
      const _FieldSpec('note', 'Note', multiline: true),
    ],
    (values) async {
      final amount = double.tryParse(values['amount'] ?? '');
      if (amount == null || amount <= 0)
        throw Exception('Enter a valid amount.');
      final proof = await _selectDepositProof();
      final result = await BackendApi.photonPayAction(
        await _token(),
        'report_deposit',
        payload: {
          'amount': amount,
          'method': values['method'],
          'reference': values['reference'] ?? '',
          'note': values['note'] ?? '',
          if (proof != null) ...proof,
        },
      );
      if (result['error'] != null) throw Exception(result['error']);
      if (mounted)
        setState(() {
          _notice = 'Deposit reported for admin review.';
          _navigationCubit.refresh();
        });
    },
  );

  Future<void> _recordClientFunds(List<Map<String, dynamic>> clients) =>
      _formDialog(
        'Record client funds',
        const [
          _FieldSpec('ownerEmail', 'Client email', required: true),
          _FieldSpec(
            'kind',
            'Type',
            required: true,
            options: const [
              _FieldOption('deposit', 'Deposit'),
              _FieldOption('adjustment', 'Balance adjustment'),
            ],
          ),
          _FieldSpec(
            'amount',
            'Amount USD (negative adjustment allowed)',
            required: true,
            keyboardType: TextInputType.number,
          ),
          _FieldSpec(
            'method',
            'Payment method',
            options: const [
              _FieldOption('bank_transfer', 'Bank transfer'),
              _FieldOption('cash', 'Cash'),
              _FieldOption('other', 'Other'),
            ],
          ),
          _FieldSpec('reference', 'Payment reference'),
          _FieldSpec('note', 'Note / adjustment reason', multiline: true),
          _FieldSpec('adminNote', 'Internal note (optional)', multiline: true),
        ],
        (values) async {
          final amount = double.tryParse(values['amount'] ?? '');
          if (amount == null || amount == 0)
            throw Exception('Enter a valid non-zero amount.');
          final email = values['ownerEmail']!.toLowerCase();
          if (clients.isNotEmpty &&
              !clients.any((c) => '${c['email']}'.toLowerCase() == email)) {
            throw Exception('Select an existing client account email.');
          }
          final proof = values['kind'] == 'adjustment'
              ? null
              : await _selectDepositProof();
          final result = await BackendApi.photonPayAction(
            await _token(),
            'wallet_record',
            payload: {
              'ownerEmail': email,
              'kind': values['kind'] == 'adjustment' ? 'adjustment' : 'deposit',
              'amount': amount,
              'method': values['method'],
              'reference': values['reference'],
              'note': values['note'],
              'adminNote': values['adminNote'],
              if (proof != null) ...proof,
            },
          );
          if (result['error'] != null) throw Exception(result['error']);
          if (mounted)
            setState(() {
              _notice = 'Client balance updated.';
              _navigationCubit.refresh();
            });
        },
      );

  Future<void> _addCardholder() async {
    final picker = ImagePicker();
    final front = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (front == null || !mounted) return;
    final back = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (back == null || !mounted) return;
    await _formDialog(
      'Register cardholder with PhotonPay',
      const [
        _FieldSpec('firstName', 'First name', required: true),
        _FieldSpec('lastName', 'Last name', required: true),
        _FieldSpec('email', 'Client account email', required: true),
        _FieldSpec('dateOfBirth', 'Date of birth', required: true, date: true),
        _FieldSpec(
          'nationalityCountryCode',
          'Nationality',
          required: true,
          country: true,
        ),
        _FieldSpec('mobilePrefix', 'Country calling code', dial: true),
        _FieldSpec('mobile', 'Mobile number'),
        _FieldSpec('residentialAddress', 'Street address', required: true),
        _FieldSpec('residentialCity', 'City', required: true),
        _FieldSpec('residentialState', 'State / province'),
        _FieldSpec('residentialPostalCode', 'Postal code', required: true),
        _FieldSpec(
          'residentialCountryCode',
          'Residence country',
          required: true,
          country: true,
        ),
        _FieldSpec(
          'certType',
          'ID document type',
          required: true,
          options: const [
            _FieldOption('passport', 'Passport'),
            _FieldOption('id_card', 'National ID card'),
            _FieldOption('resident_permit', 'Residence permit'),
          ],
        ),
        _FieldSpec('certId', 'ID number', required: true),
        _FieldSpec(
          'certCountryCode',
          'ID issuing country',
          required: true,
          country: true,
        ),
        _FieldSpec(
          'deviceCountry',
          'Country you are in now',
          required: true,
          country: true,
        ),
      ],
      (values) async {
        final token = await _token();
        Future<Map<String, dynamic>> upload(XFile file) async {
          final bytes = await file.readAsBytes();
          if (bytes.length > 6 * 1024 * 1024)
            throw Exception('Each ID photo must be 6 MB or smaller.');
          final result = await BackendApi.photonPayAction(
            token,
            'upload_id_image',
            payload: {
              'dataBase64': base64Encode(bytes),
              'fileName': file.name,
              'mimeType': file.mimeType ?? 'image/jpeg',
            },
          );
          if (result['error'] != null) throw Exception(result['error']);
          return result;
        }

        final frontResult = await upload(front);
        final backResult = values['certType'] == 'passport'
            ? <String, dynamic>{}
            : await upload(back);
        final result = await BackendApi.photonPayAction(
          token,
          'add_holder',
          payload: {
            ...values,
            'gpsCountry': values['deviceCountry'],
            'portrait': frontResult['file_key'],
            'reverseSide': backResult['file_key'] ?? '',
          },
        );
        if (result['error'] != null) throw Exception(result['error']);
        if (mounted)
          setState(() {
            _notice = 'Cardholder registration submitted to PhotonPay.';
            _navigationCubit.refresh();
          });
      },
    );
  }

  Future<void> _issueCard(List<Map<String, dynamic>> holders) => _formDialog(
    'Issue virtual card',
    [
      _FieldSpec(
        'cardholderRecordId',
        'PhotonPay cardholder',
        required: true,
        options: holders
            .where(
              (holder) => '${holder['photon_cardholder_id'] ?? ''}'.isNotEmpty,
            )
            .map(
              (holder) => _FieldOption(
                '${holder['id']}',
                '${holder['full_name'] ?? 'Client'} · ${holder['email'] ?? ''}',
                updates: {'ownerEmail': '${holder['email'] ?? ''}'},
              ),
            )
            .toList(),
        helperText: 'Choose a client synced and approved by PhotonPay.',
      ),
      const _FieldSpec('ownerEmail', 'Client email', required: true),
      const _FieldSpec(
        'currencyDisplay',
        'Currency',
        staticValue: 'USD · US Dollar',
        helperText: 'PhotonPay issues these cards in USD.',
      ),
      const _FieldSpec(
        'formatDisplay',
        'Card format',
        staticValue: 'Virtual card',
      ),
      const _FieldSpec(
        'nickname',
        'Card name',
        required: true,
        helperText: 'For example: Team travel · Q4',
      ),
      const _FieldSpec(
        'gpsCountry',
        'Issuing from',
        required: true,
        country: true,
        helperText: 'Must match the country your device is in now.',
      ),
      const _FieldSpec(
        'cardType',
        'Card type',
        required: true,
        options: [
          _FieldOption('share', 'Share card · shared balance'),
          _FieldOption('recharge', 'Regular card · separate balance'),
        ],
      ),
      const _FieldSpec(
        'rechargeAmount',
        'Opening balance (USD)',
        keyboardType: TextInputType.number,
        helperText: 'Moved from the programme USD balance onto the card.',
        visibleWhenKey: 'cardType',
        visibleWhenValue: 'recharge',
      ),
      const _FieldSpec(
        'maxOnDaily',
        'Daily limit (USD)',
        keyboardType: TextInputType.number,
      ),
      const _FieldSpec(
        'maxOnMonthly',
        'Monthly limit (USD)',
        keyboardType: TextInputType.number,
      ),
      const _FieldSpec(
        'maxOnPercent',
        'Per transaction cap (USD)',
        keyboardType: TextInputType.number,
      ),
    ],
    (values) async {
      if (holders.isNotEmpty &&
          !holders.any((h) => h['id'] == values['cardholderRecordId']))
        throw Exception(
          'Use a synced cardholder record ID from the Cardholders section.',
        );
      final response = await BackendApi.photonPayAction(
        await _token(),
        'issue',
        payload: {
          'cardholderRecordId': values['cardholderRecordId'],
          'ownerEmail': values['ownerEmail'],
          'nickname': values['nickname'],
          'gpsCountry': values['gpsCountry']?.toUpperCase(),
          'cardType': values['cardType'],
          'cardCurrency': 'USD',
          'cardFormFactor': 'virtual_card',
          if ((values['rechargeAmount'] ?? '').isNotEmpty)
            'rechargeAmount': values['rechargeAmount'],
          if ((values['maxOnDaily'] ?? '').isNotEmpty)
            'maxOnDaily': values['maxOnDaily'],
          if ((values['maxOnMonthly'] ?? '').isNotEmpty)
            'maxOnMonthly': values['maxOnMonthly'],
          if ((values['maxOnPercent'] ?? '').isNotEmpty)
            'maxOnPercent': values['maxOnPercent'],
        },
      );
      if (response['error'] != null) throw Exception(response['error']);
      final card = Map<String, dynamic>.from(response['card'] ?? {});
      final record = await BackendApi.createEntity(await _token(), 'Card', {
        'nickname': values['nickname'],
        'owner_email': response['owner_email'],
        'masked_number': card['masked_number'] ?? '',
        'last4': card['last4'] ?? '',
        'currency': 'USD',
        'card_type': values['cardType'],
        'form_factor': 'virtual_card',
        'status': card['status'] ?? 'pending',
        'balance': card['balance'] ?? 0,
        'cardholder_id': values['cardholderRecordId'],
        'cardholder_name':
            holders.firstWhere(
              (holder) => holder['id'] == values['cardholderRecordId'],
              orElse: () => <String, dynamic>{},
            )['full_name'] ??
            '',
        if ((values['maxOnDaily'] ?? '').isNotEmpty)
          'max_on_daily': num.tryParse(values['maxOnDaily']!),
        if ((values['maxOnMonthly'] ?? '').isNotEmpty)
          'max_on_monthly': num.tryParse(values['maxOnMonthly']!),
        if ((values['maxOnPercent'] ?? '').isNotEmpty)
          'max_on_percent': num.tryParse(values['maxOnPercent']!),
        'photon_card_id': card['photon_card_id'] ?? '',
        'photon_cardholder_id': response['photon_cardholder_id'] ?? '',
        'request_id': response['request_id'] ?? '',
      });
      await BackendApi.createEntity(await _token(), 'CardTransaction', {
        'kind': 'event',
        'event': 'Card requested',
        'card_id': record['id'],
        'card_last4': card['last4'] ?? '',
        'card_nickname': values['nickname'],
        'amount': 0,
        'currency': 'USD',
        'status': 'pending',
        'occurred_at': DateTime.now().toUtc().toIso8601String(),
        'owner_email': response['owner_email'] ?? '',
        'note': 'Card issued by administrator',
      });
      setState(() {
        _notice = 'Card request sent to PhotonPay.';
        _navigationCubit.refresh();
      });
    },
    initialValues: {'cardType': 'share'},
  );

  Future<void> _logout() async {
    await NotificationService.unregisterCurrentDevice();
    await FirebaseAuth.instance.signOut();
    if (mounted)
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: SizedBox(
                  width: 54,
                  height: 54,
                  child: Icon(
                    Icons.logout_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Sign out of Z8?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Your session will end on this device. You can sign in again at any time.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Stay signed in'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Sign out'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true && mounted) await _logout();
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<WorkspaceNavigationCubit, WorkspaceNavigationState>(
        bloc: _navigationCubit,
        builder: (context, _) => _buildWorkspace(context),
      );

  Widget _buildWorkspace(BuildContext context) {
    if (_loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_profile == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error ?? 'Please sign in again.'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _logout,
                  child: const Text('Back to sign in'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final title = _sections[_section] ?? 'Z8 Portal';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF81205A), Color(0xFF35122E)],
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Text(
                        'Z8',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _admin ? 'Admin workspace' : 'Z8 Portal',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFE8D8E2),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  children: _sections.entries
                      .map(
                        (entry) => ListTile(
                          selected: _section == entry.key,
                          leading: Icon(_icon(entry.key)),
                          title: Text(entry.value),
                          onTap: () {
                            Navigator.pop(context);
                            setState(() {
                              _navigationCubit.openSection(entry.key);
                              _error = null;
                              _notice = null;
                              _navigationCubit.refresh();
                            });
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sign out'),
                onTap: _confirmLogout,
              ),
            ],
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<dynamic>(
          key: ValueKey('$_section-$_revision'),
          future: _loadSection(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done)
              return ListView(
                children: [
                  SizedBox(
                    height: 280,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
              );
            if (snapshot.hasError)
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _message(_friendly(snapshot.error!), error: true),
                  FilledButton(
                    onPressed: _refresh,
                    child: const Text('Try again'),
                  ),
                ],
              );
            return _sectionBody(snapshot.data);
          },
        ),
      ),
      bottomNavigationBar: WorkspaceBottomBar(
        isAdmin: _admin,
        selectedIndex: _bottomIndex,
        onSelected: (index) {
          final destinations = _admin
              ? ['home', 'cards', 'clients', 'funds']
              : ['home', 'cards', 'activity', 'account'];
          setState(() {
            _navigationCubit.openSection(destinations[index]);
            _navigationCubit.refresh();
          });
        },
      ),
    );
  }
}

class AssistantConversationPage extends StatefulWidget {
  const AssistantConversationPage({
    super.key,
    required this.conversation,
    required this.agent,
    required this.sections,
    required this.onNavigate,
    required this.onLogout,
  });
  final Map<String, dynamic> conversation;
  final String agent;
  final Map<String, String> sections;
  final ValueChanged<String> onNavigate;
  final Future<void> Function() onLogout;
  @override
  State<AssistantConversationPage> createState() =>
      _AssistantConversationPageState();
}

class _AssistantConversationPageState extends State<AssistantConversationPage> {
  final _controller = TextEditingController();
  late List<Map<String, dynamic>> _messages;
  bool _sending = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _messages = (widget.conversation['messages'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> _send() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    _controller.clear();
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final response = await BackendApi.sendAssistantMessage(
        (await user.getIdToken(true))!,
        '${widget.conversation['id']}',
        content,
      );
      setState(
        () => _messages = (response['messages'] as List? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(),
      );
    } catch (error) {
      _controller.text = content;
      setState(
        () => _error = error is BackendApiException
            ? error.message
            : error.toString(),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  bool get _admin => widget.agent != 'cardholder_assistant';

  int get _selectedTab {
    final tabs = _admin
        ? ['home', 'cards', 'clients', 'funds']
        : ['home', 'cards', 'activity', 'account'];
    final activeSection = widget.agent == 'technical_support'
        ? 'support'
        : 'assistant';
    final index = tabs.indexOf(activeSection);
    // Assistant and support are available from the hamburger menu, outside
    // the four primary tabs, so keep the first tab selected on this subpage.
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.agent == 'technical_support'
            ? 'Technical support'
            : 'Card assistant',
      ),
    ),
    drawer: Drawer(
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.credit_card_rounded),
              ),
              title: Text(_admin ? 'Admin workspace' : 'Z8 Portal'),
              subtitle: Text(FirebaseAuth.instance.currentUser?.email ?? ''),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                children: [
                  for (final entry in widget.sections.entries)
                    ListTile(
                      leading: Icon(switch (entry.key) {
                        'home' => Icons.space_dashboard_rounded,
                        'cards' => Icons.credit_card_rounded,
                        'clients' => Icons.groups_2_rounded,
                        'funds' ||
                        'wallet' => Icons.account_balance_wallet_rounded,
                        'activity' => Icons.receipt_long_rounded,
                        'verification' => Icons.verified_user_rounded,
                        'connection' => Icons.account_tree_rounded,
                        'assistant' || 'support' => Icons.support_agent_rounded,
                        'notifications' => Icons.notifications_active_rounded,
                        _ => Icons.account_circle_rounded,
                      }),
                      title: Text(entry.value),
                      selected: entry.key == (_admin ? 'support' : 'assistant'),
                      onTap: () {
                        Navigator.pop(context);
                        widget.onNavigate(entry.key);
                      },
                    ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign out'),
              onTap: () async {
                Navigator.pop(context);
                await widget.onLogout();
              },
            ),
          ],
        ),
      ),
    ),
    body: Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final message in _messages)
                Align(
                  alignment: message['role'] == 'user'
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Card(
                    color: message['role'] == 'user'
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('${message['content'] ?? ''}'),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Ask your question',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
    bottomNavigationBar: WorkspaceBottomBar(
      isAdmin: _admin,
      selectedIndex: _selectedTab,
      onSelected: (index) {
        final sections = _admin
            ? ['home', 'cards', 'clients', 'funds']
            : ['home', 'cards', 'activity', 'account'];
        widget.onNavigate(sections[index]);
      },
    ),
  );
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _FieldSpec {
  const _FieldSpec(
    this.key,
    this.label, {
    this.required = false,
    this.keyboardType,
    this.options,
    this.helperText,
    this.multiline = false,
    this.date = false,
    this.country = false,
    this.dial = false,
    this.visibleWhenKey,
    this.visibleWhenValue,
    this.staticValue,
  });
  final String key, label;
  final bool required;
  final TextInputType? keyboardType;
  final List<_FieldOption>? options;
  final String? helperText;
  final bool multiline;
  final bool date;
  final bool country;
  final bool dial;
  final String? visibleWhenKey;
  final String? visibleWhenValue;
  final String? staticValue;
}

class _FieldOption {
  const _FieldOption(this.value, this.label, {this.updates = const {}});
  final String value;
  final String label;
  final Map<String, String> updates;
}
