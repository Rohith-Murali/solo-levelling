import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class ApiClient {
  ApiClient({Uri? baseUri, http.Client? client})
    : _baseUri = baseUri ?? Uri.parse(AppConfig.apiBaseUrl),
      _client = client ?? http.Client(),
      _ownsClient = client == null;

  final Uri _baseUri;
  final http.Client _client;
  final bool _ownsClient;

  Future<Map<String, dynamic>> getJson(String path) async {
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    late final http.Response response;

    try {
      response = await _client
          .get(_baseUri.resolve(normalizedPath))
          .timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw const ApiException('The request timed out.');
    } on http.ClientException {
      throw const ApiException('Unable to reach the server.');
    }

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
      final message = errorMessage is String
          ? errorMessage
          : 'The request failed with status ${response.statusCode}.';
      throw ApiException(message, statusCode: response.statusCode);
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
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException: $message';
}
