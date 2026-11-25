import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:solo_levelling/core/network/api_client.dart';
import 'package:solo_levelling/features/dashboard/data/dashboard_api.dart';

void main() {
  test(
    'loads authenticated dashboard data from the dashboard endpoint',
    () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/dashboard');
        expect(request.headers['authorization'], 'Bearer access-token');

        return http.Response(
          jsonEncode({
            'data': {
              'character': {
                'id': 'character-id',
                'name': 'Hunter',
                'avatarId': 'avatar-01',
                'avatarImagePath': 'avatars/Avatar 1.png',
                'rank': 'E',
                'title': 'Shadow Initiate',
                'level': 1,
                'totalXp': 0,
                'currentLevelXp': 0,
                'xpToNextLevel': 100,
                'skillUnlockTokens': 0,
              },
              'statistics': {
                'completedQuestCount': 0,
                'activeQuestCount': 0,
                'acquiredSkillCount': 1,
                'achievementCount': 0,
                'completedGoalCount': 0,
                'completedMilestoneCount': 0,
              },
              'activeQuests': [],
              'skills': [
                {
                  'id': 'focus',
                  'name': 'Focus',
                  'level': 1,
                  'currentLevelXp': 0,
                  'xpToNextLevel': 100,
                },
              ],
              'progressionOverview': {
                'period': 'LAST_30_DAYS',
                'characterXpEarned': null,
                'questsCompleted': null,
                'goalsCompleted': null,
                'milestonesCompleted': null,
                'xpTrend': [],
              },
              'recentActivity': [],
            },
          }),
          200,
        );
      });
      final api = DashboardApi(
        ApiClient(
          baseUri: Uri.parse('http://localhost:3000/api/'),
          client: mockClient,
        ),
      );

      final dashboard = await api.getDashboard('access-token');

      expect(dashboard.character.name, 'Hunter');
      expect(dashboard.character.title, 'Shadow Initiate');
      expect(dashboard.character.currentLevelXp, 0);
      expect(dashboard.skills.single.name, 'Focus');
      expect(dashboard.progressionOverview.characterXpEarned, isNull);
      expect(dashboard.activeQuests, isEmpty);
      mockClient.close();
    },
  );
}
