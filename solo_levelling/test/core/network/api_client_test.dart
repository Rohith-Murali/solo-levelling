import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:solo_levelling/core/network/api_client.dart';

void main() {
  test('resolves API paths below the configured base URI', () async {
    final mockClient = MockClient((request) async {
      expect(request.url.path, '/api/health/live');
      return http.Response(
        jsonEncode({
          'data': {'status': 'ok'},
        }),
        200,
      );
    });
    final apiClient = ApiClient(
      baseUri: Uri.parse('http://localhost:3000/api/'),
      client: mockClient,
    );

    expect(await apiClient.getJson('health/live'), {
      'data': {'status': 'ok'},
    });
    mockClient.close();
  });

  test(
    'sends PATCH and DELETE requests with their respective methods',
    () async {
      final methods = <String>[];
      final mockClient = MockClient((request) async {
        methods.add(request.method);
        return http.Response(jsonEncode({'data': {}}), 200);
      });
      final apiClient = ApiClient(
        baseUri: Uri.parse('http://localhost:3000/api/'),
        client: mockClient,
      );

      await apiClient.patchJson('quests/goals/goal-1', body: const {});
      await apiClient.deleteJson('quests/goals/goal-1');

      expect(methods, ['PATCH', 'DELETE']);
      mockClient.close();
    },
  );

  test('maps API error responses to ApiException', () async {
    final mockClient = MockClient((_) async {
      return http.Response(
        jsonEncode({
          'error': {'code': 'NOT_FOUND', 'message': 'Route not found.'},
        }),
        404,
      );
    });
    final apiClient = ApiClient(
      baseUri: Uri.parse('http://localhost:3000/api/'),
      client: mockClient,
    );

    await expectLater(
      apiClient.getJson('missing'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 404)
            .having((error) => error.message, 'message', 'Route not found.'),
      ),
    );
    mockClient.close();
  });

  test(
    'refreshes an expired access token and retries the request once',
    () async {
      var requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        expect(
          request.headers['authorization'],
          'Bearer ${requestCount == 1 ? 'expired-token' : 'fresh-token'}',
        );
        return requestCount == 1
            ? http.Response(
                jsonEncode({
                  'error': {
                    'code': 'INVALID_ACCESS_TOKEN',
                    'message': 'Your session is invalid or expired.',
                  },
                }),
                401,
              )
            : http.Response(
                jsonEncode({
                  'data': {'status': 'ok'},
                }),
                200,
              );
      });
      final apiClient = ApiClient(
        baseUri: Uri.parse('http://localhost:3000/api/'),
        client: mockClient,
      )..onAccessTokenExpired = () async => 'fresh-token';

      expect(
        await apiClient.getJson('health/live', bearerToken: 'expired-token'),
        {
          'data': {'status': 'ok'},
        },
      );
      expect(requestCount, 2);
      mockClient.close();
    },
  );
}
