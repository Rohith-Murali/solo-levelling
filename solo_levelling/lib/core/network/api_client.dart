import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class ApiClient {
  ApiClient({Uri? baseUri, http.Client? client})
    : _baseUri = baseUri ?? Uri.parse(AppConfig.apiBaseUrl),
      _client = client ?? http.Client(),
      _ownsClient = client == null;

  Future<String?> Function()? onAccessTokenExpired;

  final Uri _baseUri;
  final http.Client _client;
  final bool _ownsClient;

  Future<Map<String, dynamic>> getJson(
    String path, {
    String? bearerToken,
  }) async {
    return _request('GET', path, bearerToken: bearerToken);
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, Object?> body,
    String? bearerToken,
  }) async {
    return _request('POST', path, body: body, bearerToken: bearerToken);
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, Object?>? body,
    String? bearerToken,
  }) async {
    if (method != 'GET' && method != 'POST') {
      throw ArgumentError.value(
        method,
        'method',
        'Only GET and POST are supported.',
      );
    }

    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) {
      headers['Content-Type'] = 'application/json';
    }
    if (bearerToken != null) {
      headers['Authorization'] = 'Bearer $bearerToken';
    }
    final response = await _send(method, normalizedPath, headers, body);

    if (response.statusCode == 401 &&
        bearerToken != null &&
        onAccessTokenExpired != null) {
      final refreshedToken = await onAccessTokenExpired!();
      if (refreshedToken != null && refreshedToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $refreshedToken';
        final retryResponse = await _send(
          method,
          normalizedPath,
          headers,
          body,
        );
        return _decodeResponse(retryResponse);
      }
    }

    return _decodeResponse(response);
  }

  Future<http.Response> _send(
    String method,
    String path,
    Map<String, String> headers,
    Map<String, Object?>? body,
  ) async {
    try {
      final uri = _baseUri.resolve(path);
      return await (method == 'GET'
              ? _client.get(uri, headers: headers)
              : _client.post(uri, headers: headers, body: jsonEncode(body)))
          .timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw const ApiException('The request timed out.');
    } on http.ClientException {
      throw const ApiException('Unable to reach the server.');
    }
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw ApiException(
        'The server returned an invalid response.',
        statusCode: response.statusCode,
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw ApiException(
        'The server returned an invalid response.',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded['error'];
      final errorMessage = error is Map<String, dynamic>
          ? error['message']
          : null;
      final errorCode = error is Map<String, dynamic> ? error['code'] : null;
      final message = errorMessage is String
          ? errorMessage
          : 'The request failed with status ${response.statusCode}.';
      throw ApiException(
        message,
        statusCode: response.statusCode,
        code: errorCode is String ? errorCode : null,
      );
    }

    return decoded;
  }

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }
}

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  @override
  String toString() => 'ApiException: $message';
}
