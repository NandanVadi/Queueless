import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:queueless/screens/admin_dashboard_screen.dart';
import 'package:queueless/services/api_service.dart';

void main() {
  Widget createWidgetUnderTest() {
    return const MaterialApp(
      home: Scaffold(
        body: AdminDashboardScreen(),
      ),
    );
  }

  testWidgets('AdminDashboardScreen shows loading initially', (tester) async {
    ApiService.globalTestClient = MockClient((request) async {
      await Future.delayed(const Duration(milliseconds: 50));
      return http.Response('{"error": "Failed"}', 500);
    });

    await tester.pumpWidget(createWidgetUnderTest());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('AdminDashboardScreen shows dashboard data', (tester) async {
    ApiService.globalTestClient = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'dashboard': {
            'users': {'total': 42},
            'queue': {'today': 10, 'waiting': 3},
            'appointments': {'today': 5},
            'services': [
              {
                'id': 1,
                'name': 'Medical',
                'isActive': true,
                'queue': {'today': 2, 'completed': 5},
                'appointments': {'today': 0},
                'peopleWaiting': 2,
                'estimatedWaitTime': 20,
              }
            ]
          }
        }),
        200,
      );
    });
    ApiService.authToken = 'fake-admin';

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('Total Users'), findsOneWidget);
    expect(find.text('42'), findsOneWidget); // Total users
    
    expect(find.text('Queue Overview'), findsOneWidget);
    expect(find.text('10'), findsOneWidget); // Queue today
    
    expect(find.text('Service Overview'), findsOneWidget);
    expect(find.text('Medical'), findsOneWidget);
  });

  testWidgets('AdminDashboardScreen shows error state and can retry', (tester) async {
    int reqCount = 0;
    ApiService.globalTestClient = MockClient((request) async {
      reqCount++;
      if (reqCount == 1) {
        return http.Response(jsonEncode({'error': 'Server down'}), 500);
      }
      return http.Response(
        jsonEncode({
          'dashboard': {
            'users': {'total': 1},
            'queue': {},
            'appointments': {},
            'services': []
          }
        }),
        200,
      );
    });
    ApiService.authToken = 'fake-admin';

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('Failed to load dashboard'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Failed to load dashboard'), findsNothing);
    expect(find.text('Total Users'), findsOneWidget);
  });
}
