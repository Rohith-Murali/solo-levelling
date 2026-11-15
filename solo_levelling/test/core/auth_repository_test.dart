import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:solo_levelling/core/network/api_client.dart';
import 'package:solo_levelling/features/auth/data/auth_api.dart';
import 'package:solo_levelling/features/auth/data/auth_repository_impl.dart';
import 'package:solo_levelling/features/auth/data/refresh_token_storage.dart';

void main() {
  test('restores a session and saves the rotated refresh token', () async {
    final responses = <http.Response>[
      http.Response(
        jsonEncode({
          'data': {
            'user': {'id': 'user-id', 'email': 'hunter@example.com'},
            'accessToken': 'new-access-token',
            'refreshToken': 'new-refresh-token',
            'tokenType': 'Bearer',
            'expiresIn': 900,
          },
        }),
        200,
      ),
      http.Response(
        jsonEncode({
          'data': {
            'user': {'id': 'user-id', 'email': 'hunter@example.com'},
          },
        }),
        200,
      ),
    ];
    final mockClient = MockClient((request) async {
      if (request.url.path == '/api/auth/refresh') {
        expect(jsonDecode(request.body), {'refreshToken': 'old-refresh-token'});
      } else {
        expect(request.url.path, '/api/auth/me');
        expect(request.headers['authorization'], 'Bearer new-access-token');
      }
      return responses.removeAt(0);
    });
    final repository = AuthRepositoryImpl(
      api: AuthApi(
        ApiClient(
          baseUri: Uri.parse('http://localhost:3000/api/'),
          client: mockClient,
        ),
      ),
      tokenStorage: _MemoryTokenStorage('old-refresh-token'),
    );

    final user = await repository.restoreSession();

    expect(user?.email, 'hunter@example.com');
    expect(repository.accessToken, 'new-access-token');
    mockClient.close();
  });

  test('clears an expired refresh token', () async {
    final mockClient = MockClient((_) async {
      return http.Response(
        jsonEncode({
          'error': {'code': 'INVALID_SESSION', 'message': 'Session expired.'},
        }),
        401,
      );
    });
    final storage = _MemoryTokenStorage('expired-refresh-token');
    final repository = AuthRepositoryImpl(
      api: AuthApi(
        ApiClient(
          baseUri: Uri.parse('http://localhost:3000/api/'),
          client: mockClient,
        ),
      ),
      tokenStorage: storage,
    );

    expect(await repository.restoreSession(), isNull);
    expect(storage.token, isNull);
    expect(repository.accessToken, isNull);
    mockClient.close();
  });
}

class _MemoryTokenStorage implements RefreshTokenStorage {
  _MemoryTokenStorage(this.token);

  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async {
    token = value;
  }

  @override
  Future<void> clear() async {
    token = null;
  }
}
