import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:solo_levelling/core/network/api_client.dart';
import 'package:solo_levelling/features/progression/data/progression_api.dart';

void main() {
  test(
    'parses quests and completes quests through the progression API',
    () async {
      final mockClient = MockClient((request) async {
        expect(request.headers['authorization'], 'Bearer token');
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'data': {
                'quests': [
                  {
                    'id': 'quest-1',
                    'title': 'Begin',
                    'description': 'Start.',
                    'type': 'MAIN',
                    'difficulty': 'EASY',
                    'primarySkillId': 'focus',
                    'completed': false,
                  },
                ],
              },
            }),
            200,
          );
        }
        expect(request.url.path, '/api/quests/quest-1/complete');
        return http.Response(jsonEncode({'data': {}}), 200);
      });
      final api = ProgressionApi(
        ApiClient(
          baseUri: Uri.parse('http://localhost:3000/api/'),
          client: mockClient,
        ),
      );

      await api.getQuests('token');
      await api.completeQuest('token', 'quest-1');
      mockClient.close();
    },
  );

  test(
    'loads and acquires library or custom skills with authentication',
    () async {
      final mockClient = MockClient((request) async {
        expect(request.headers['authorization'], 'Bearer token');
        if (request.method == 'GET') {
          expect(request.url.path, '/api/skills/library');
          return http.Response(
            jsonEncode({
              'data': {
                'skills': [
                  {
                    'id': 'fitness',
                    'name': 'Fitness',
                    'description': 'Build physical health.',
                  },
                ],
              },
            }),
            200,
          );
        }

        expect(request.url.path, '/api/skills/acquire');
        expect(jsonDecode(request.body), {
          'name': 'Creative writing',
          'description': 'Practice writing clearly.',
          'category': 'CREATIVE',
        });
        return http.Response(
          jsonEncode({
            'data': {'skill': {}},
          }),
          201,
        );
      });
      final api = ProgressionApi(
        ApiClient(
          baseUri: Uri.parse('http://localhost:3000/api/'),
          client: mockClient,
        ),
      );

      expect((await api.getSkillLibrary('token')).single.id, 'fitness');
      await api.acquireSkill(
        'token',
        name: 'Creative writing',
        description: 'Practice writing clearly.',
        category: 'CREATIVE',
      );
      mockClient.close();
    },
  );
}
