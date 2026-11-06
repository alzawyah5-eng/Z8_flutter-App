import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class BackendApiException implements Exception {
  const BackendApiException(
    this.code,
    this.message, {
    this.details,
    this.statusCode,
  });

  final String? code;
  final String message;
  final String? details;
  final int? statusCode;

  @override
  String toString() {
    if (details != null && details!.isNotEmpty) {
      return '$message ($details)';
    }
    return message;
  }
}

class BackendApi {
  static const _baseUrl = String.fromEnvironment(
    'Z8_API_BASE_URL',
    // Current ngrok HTTPS tunnel to the local Z8 API.
    defaultValue: 'https://caramel-unrented-thank.ngrok-free.dev/v1',
  );

  static String get baseUrl => _baseUrl;

  static Future<Map<String, dynamic>> registerOrGetMe(String idToken) =>
      _request('POST', '/me', idToken: idToken);

  static Future<Map<String, dynamic>> getMe(String idToken) =>
      _request('GET', '/me', idToken: idToken);

  static Future<Map<String, dynamic>> exchangeGoogleIdToken(String idToken) =>
      _request('POST', '/auth/google/session', body: {'idToken': idToken});

  static Future<Map<String, dynamic>> registerWithPassword(
    String email,
    String password,
  ) => _request(
    'POST',
    '/auth/password/register',
    body: {'email': email, 'password': password},
  );

  static Future<Map<String, dynamic>> verifyPasswordRegistration(
    String email,
    String code,
  ) => _request(
    'POST',
    '/auth/password/register/verify',
    body: {'email': email, 'code': code},
  );

  static Future<Map<String, dynamic>> resendRegistrationCode(String email) =>
      _request(
        'POST',
        '/auth/password/register/resend-verification',
        body: {'email': email},
      );

  static Future<Map<String, dynamic>> loginWithPassword(
    String email,
    String password,
  ) => _request(
    'POST',
    '/auth/password/login',
    body: {'email': email, 'password': password},
  );

  static Future<Map<String, dynamic>> requestPasswordReset(String email) =>
      _request('POST', '/auth/password/reset/request', body: {'email': email});

  static Future<Map<String, dynamic>> confirmPasswordReset({
    required String email,
    required String token,
    required String password,
  }) => _request(
    'POST',
    '/auth/password/reset/confirm',
    body: {'email': email, 'token': token, 'password': password},
  );

  static Future<void> migrateLegacyPassword(
    String idToken,
    String password,
  ) async {
    await _request(
      'POST',
      '/auth/password/migrate-legacy',
      idToken: idToken,
      body: {'password': password},
    );
  }

  static Future<Map<String, dynamic>> sendNotificationTest(String idToken) =>
      _request('POST', '/me/notifications/test', idToken: idToken);

  static Future<Map<String, dynamic>> deleteAccount(
    String idToken,
    String email,
  ) => _request(
    'POST',
    '/functions/deleteAccount',
    idToken: idToken,
    body: {'confirm_email': email},
  );

  static Future<Map<String, dynamic>> photonPayAction(
    String idToken,
    String action, {
    Map<String, Object?> payload = const {},
  }) => _request(
    'POST',
    '/functions/photonpayCards',
    idToken: idToken,
    body: {'action': action, 'payload': payload},
  );

  static Future<Map<String, dynamic>> photonPayDiagnostics(String idToken) =>
      _request(
        'POST',
        '/functions/photonpayDiagnostics',
        idToken: idToken,
        body: const {},
      );

  static Future<Map<String, dynamic>> queryEntity(
    String idToken,
    String entity, {
    Map<String, Object?> filter = const {},
    String? sort,
    int limit = 50,
    String? cursor,
  }) => _request(
    'POST',
    '/entities/$entity/query',
    idToken: idToken,
    body: {
      'filter': filter,
      if (sort != null) 'sort': sort,
      'limit': limit,
      if (cursor != null) 'cursor': cursor,
    },
  );

  static Future<Map<String, dynamic>> countEntity(
    String idToken,
    String entity, {
    Map<String, Object?> filter = const {},
  }) => _request(
    'POST',
    '/entities/$entity/count',
    idToken: idToken,
    body: {'filter': filter},
  );

  static Future<Map<String, dynamic>> createEntity(
    String idToken,
    String entity,
    Map<String, Object?> data,
  ) => _request(
    'POST',
    '/entities/$entity',
    idToken: idToken,
    body: {'data': data},
  );

  static Future<Map<String, dynamic>> updateEntity(
    String idToken,
    String entity,
    String id,
    Map<String, Object?> data,
  ) => _request(
    'PATCH',
    '/entities/$entity/${Uri.encodeComponent(id)}',
    idToken: idToken,
    body: {'data': data},
  );

  static Future<Map<String, dynamic>> assistantConversations(
    String idToken,
    String agentName,
  ) => _request(
    'GET',
    '/agents/conversations?agent_name=${Uri.encodeQueryComponent(agentName)}',
    idToken: idToken,
  );

  static Future<Map<String, dynamic>> createAssistantConversation(
    String idToken,
    String agentName,
  ) => _request(
    'POST',
    '/agents/conversations',
    idToken: idToken,
    body: {'agent_name': agentName, 'metadata': <String, Object?>{}},
  );

  static Future<Map<String, dynamic>> sendAssistantMessage(
    String idToken,
    String conversationId,
    String content,
  ) => _request(
    'POST',
    '/agents/conversations/${Uri.encodeComponent(conversationId)}/messages',
    idToken: idToken,
    body: {'role': 'user', 'content': content},
  );

  static Future<void> registerDevice(
    String idToken,
    String token,
    String platform,
  ) async {
    await _request(
      'POST',
      '/me/devices',
      idToken: idToken,
      body: {'token': token, 'platform': platform},
    );
  }

  static Future<void> removeDevice(String idToken, String token) async {
    await _request(
      'DELETE',
      '/me/devices',
      idToken: idToken,
      body: {'token': token},
    );
  }

  static Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    String? idToken,
    Map<String, Object?>? body,
  }) async {
    final base = Uri.parse(_baseUrl);
    if (!kDebugMode && base.scheme != 'https') {
      throw const BackendApiException(
        'invalid_api_url',
        'The secure Z8 API address is not configured.',
      );
    }

    final uri = Uri.parse(
      '${base.toString().replaceFirst(RegExp(r'/+$'), '')}/'
      '${path.replaceFirst(RegExp(r'^/+'), '')}',
    );
    final headers = <String, String>{
      'accept': 'application/json',
      // Bypass ngrok's free-tier HTML interstitial for native API requests.
      'ngrok-skip-browser-warning': '1',
    };
    if (idToken != null) headers['authorization'] = 'Bearer $idToken';
    if (body != null) headers['content-type'] = 'application/json';

    try {
      final requestBody = body == null ? null : jsonEncode(body);
      final response = switch (method) {
        'GET' =>
          await http
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 15)),
        'POST' =>
          await http
              .post(uri, headers: headers, body: requestBody)
              .timeout(const Duration(seconds: 15)),
        'PATCH' =>
          await http
              .patch(uri, headers: headers, body: requestBody)
              .timeout(const Duration(seconds: 15)),
        'DELETE' =>
          await http
              .delete(uri, headers: headers)
              .timeout(const Duration(seconds: 15)),
        _ => throw StateError('Unsupported HTTP method.'),
      };
      final dynamic decodedBody;
      try {
        decodedBody = response.body.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(response.body);
      } on FormatException {
        if (kDebugMode) {
          final contentType = response.headers['content-type'] ?? 'unknown';
          final compactBody = response.body.replaceAll(RegExp(r'\s+'), ' ');
          final bodyStart = compactBody.substring(
            0,
            compactBody.length > 120 ? 120 : compactBody.length,
          );
          debugPrint(
            '[Z8 API] $method ${uri.path} returned non-JSON HTTP ${response.statusCode}; '
            'content-type=$contentType; body-start="$bodyStart"',
          );
        }
        throw const BackendApiException(
          'invalid_response',
          'The Z8 API returned an invalid response. Check that the ngrok tunnel points to the Z8 backend.',
        );
      }
      if (decodedBody is! Map<String, dynamic>) {
        if (kDebugMode) {
          debugPrint(
            '[Z8 API] $method ${uri.path} returned JSON type ${decodedBody.runtimeType}, '
            'expected an object; HTTP ${response.statusCode}.',
          );
        }
        throw const BackendApiException(
          'invalid_response',
          'The Z8 API returned an invalid response. Check that the ngrok tunnel points to the Z8 backend.',
        );
      }
      final data = decodedBody;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final code = data['code'] as String?;
        final rawMessage = data['message'] ?? data['error'];
        final details = data['details'] as String?;
        if (kDebugMode) {
          debugPrint(
            '[Z8 API] $method ${uri.path} failed with HTTP ${response.statusCode}; code=${code ?? 'none'}.',
          );
        }
        final message = code == 'user_not_registered'
            ? 'This account is not registered for Z8. Contact the administrator to request access.'
            : response.statusCode == 404
            ? 'The backend route is unavailable. Check the API address and restart the backend.'
            : rawMessage is String
            ? rawMessage
            : 'The Z8 service could not complete sign-in. Please try again.';
        throw BackendApiException(
          code,
          message,
          details: details,
          statusCode: response.statusCode,
        );
      }
      return data;
    } on BackendApiException {
      rethrow;
    } on FormatException {
      throw const BackendApiException(
        'invalid_response',
        'The Z8 service returned an unexpected response.',
      );
    } catch (_) {
      throw const BackendApiException(
        'service_unavailable',
        'Cannot reach the Z8 service. Check that the backend is running and the device can reach it.',
      );
    }
  }
}
