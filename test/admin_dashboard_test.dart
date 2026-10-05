import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:queueless/models/dashboard.dart';
import 'package:queueless/services/api_service.dart';

void main() {
  group('Dashboard Models', () {
    test('parses complete dashboard JSON', () {
      final jsonStr = '''
      {
        "users": {
          "total": 10,
          "operators": 2,
          "admins": 1
        },
        "queue": {
          "total": 50,
          "today": 5,
          "waiting": 2,
          "serving": 1,
          "completed": 45,
          "cancelled": 2,
          "todayCompleted": 2,
          "todayCancelled": 0
        },
        "appointments": {
          "total": 20,
          "today": 3,
          "scheduled": 5,
          "completed": 12,
          "cancelled": 3
        },
        "services": [
          {
            "id": 1,
            "name": "General",
            "isActive": true,
            "queue": {
              "total": 25,
              "today": 2,
              "waiting": 1,
              "serving": 0,
              "completed": 20,
              "cancelled": 1,
              "todayCompleted": 0,
              "todayCancelled": 0
            },
            "appointments": {
              "total": 10,
              "today": 1,
              "scheduled": 2,
              "completed": 6,
              "cancelled": 1
            },
            "currentServingToken": null,
            "peopleWaiting": 1,
            "estimatedWaitTime": 10
          }
        ]
      }
      ''';

      final json = jsonDecode(jsonStr);
      final dashboard = DashboardData.fromJson(json);

      expect(dashboard.users.total, 10);
      expect(dashboard.users.operators, 2);
      expect(dashboard.queue.waiting, 2);
      expect(dashboard.appointments.scheduled, 5);
      
      expect(dashboard.services.length, 1);
      final service = dashboard.services.first;
      expect(service.id, 1);
      expect(service.name, 'General');
      expect(service.queue.total, 25);
      expect(service.peopleWaiting, 1);
      expect(service.estimatedWaitTime, 10);
      expect(service.currentServingToken, isNull);
    });

    test('handles empty data gracefully', () {
      final dashboard = DashboardData.fromJson({});
      expect(dashboard.users.total, 0);
      expect(dashboard.queue.total, 0);
      expect(dashboard.services, isEmpty);
    });
  });

  group('ApiService Dashboard API', () {
    test('getAdminDashboard returns data on 200', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'dashboard': {
              'users': {'total': 1},
              'queue': {'total': 0},
              'appointments': {'total': 0},
              'services': []
            }
          }),
          200,
        );
      });

      final apiService = ApiService(client: mockClient);
      ApiService.authToken = 'fake-admin-token';

      final data = await apiService.getAdminDashboard();
      expect(data.users.total, 1);
    });

    test('getAdminDashboard throws on 403', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'error': 'Forbidden'}), 403);
      });

      final apiService = ApiService(client: mockClient);
      ApiService.authToken = 'fake-user-token';

      expect(
        () => apiService.getAdminDashboard(),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
