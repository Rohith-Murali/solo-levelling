import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:solo_levelling/core/network/api_client.dart';
import 'package:solo_levelling/features/progression/data/progression_api.dart';

void main() {
  test('loads templates and sends authenticated activation requests', () async {
    final mockClient = MockClient((request) async {
      expect(request.headers['authorization'], 'Bearer token');
      if (request.method == 'GET') {
        expect(request.url.path, '/api/quests/templates');
        return http.Response(
          jsonEncode({
            'data': {
              'templates': [
                {
                  'id': 'body',
                  'name': 'Body',
                  'description': 'Build strength.',
                  'minimumLevel': 1,
                  'milestoneCount': 3,
                  'questCount': 9,
                },
              ],
            },
          }),
          200,
        );
      }
      expect(request.method, 'POST');
      expect(request.url.path, '/api/quests/templates/body/activate');
      return http.Response(jsonEncode({'data': {}}), 201);
    });
    final api = ProgressionApi(
      ApiClient(
        baseUri: Uri.parse('http://localhost:3000/api/'),
        client: mockClient,
      ),
    );

    expect((await api.getTemplates('token')).single.name, 'Body');
    await api.activateTemplate('token', 'body');
    mockClient.close();
  });

  test(
    'parses quests and completes objectives through the progression API',
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
                    'sourceTemplateId': 'mind',
                    'objectives': [
                      {
                        'id': 'objective-1',
                        'title': 'Start',
                        'completed': false,
                      },
                    ],
                    'completed': false,
                  },
                ],
              },
            }),
            200,
          );
        }
        expect(
          request.url.path,
          '/api/quests/quest-1/objectives/objective-1/complete',
        );
        return http.Response(jsonEncode({'data': {}}), 200);
      });
      final api = ProgressionApi(
        ApiClient(
          baseUri: Uri.parse('http://localhost:3000/api/'),
          client: mockClient,
        ),
      );

      final quests = await api.getQuests('token');
      expect(quests.single.objectives.single.title, 'Start');
      expect(quests.single.sourceTemplateId, 'mind');
      await api.completeObjective('token', 'quest-1', 'objective-1');
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
