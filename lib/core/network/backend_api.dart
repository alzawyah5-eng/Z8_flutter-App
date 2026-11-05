import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class BackendApiException implements Exception {
  const BackendApiException(this.code, this.message, {this.details, this.statusCode});

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
    defaultValue: 'http://127.0.0.1:3000/v1',
  );

  static String get baseUrl => _baseUrl;

  static Future<Map<String, dynamic>> registerOrGetMe(String idToken) =>
      _request('POST', '/me', idToken: idToken);

  static Future<Map<String, dynamic>> getMe(String idToken) =>
      _request('GET', '/me', idToken: idToken);

  static Future<Map<String, dynamic>> exchangeGoogleIdToken(String idToken) =>
      _request('POST', '/auth/google/session', body: {'idToken': idToken});

  static Future<void> registerDevice(
    String idToken,
    String token,
    String platform,
  ) async {
    await _request('POST', '/me/devices', idToken: idToken,
        body: {'token': token, 'platform': platform});
  }

  static Future<void> removeDevice(String idToken, String token) async {
    await _request('DELETE', '/me/devices', idToken: idToken,
        body: {'token': token});
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
    final headers = <String, String>{'accept': 'application/json'};
    if (idToken != null) headers['authorization'] = 'Bearer $idToken';
    if (body != null) headers['content-type'] = 'application/json';

    try {
      final requestBody = body == null ? null : jsonEncode(body);
      final response = switch (method) {
        'GET' => await http.get(uri, headers: headers).timeout(
          const Duration(seconds: 15),
        ),
        'POST' => await http.post(uri, headers: headers, body: requestBody).timeout(
          const Duration(seconds: 15),
        ),
        'DELETE' => await http.delete(uri, headers: headers).timeout(
          const Duration(seconds: 15),
        ),
        _ => throw StateError('Unsupported HTTP method.'),
      };
      final data = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final code = data['code'] as String?;
        final rawMessage = data['message'];
        final details = data['details'] as String?;
        final message = rawMessage is String
            ? rawMessage
            : code == 'user_not_registered'
            ? 'This account is not registered for Z8. Contact the administrator to request access.'
            : 'The Z8 service could not complete sign-in. Please try again.';
        throw BackendApiException(code, message, details: details, statusCode: response.statusCode);
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
