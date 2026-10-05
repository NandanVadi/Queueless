import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:queueless/services/api_service.dart';
import 'dart:convert';
import 'package:queueless/database/database_helper.dart';
import 'package:queueless/main.dart';
import 'package:queueless/screens/main_screen.dart';
import 'package:queueless/models/queue_token.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    DatabaseHelper.instance.setDatabasePathForTesting(inMemoryDatabasePath);
    await DatabaseHelper.instance.database;
  });

  setUp(() async {
    ApiService.globalTestClient = MockClient((request) async {
      if (request.method == 'POST' && request.url.path.endsWith('/api/queue')) {
        return http.Response(
          jsonEncode({
            'queueToken': {
              'id': 1,
              'serviceId': 1,
              'tokenNumber': 1,
              'status': 'waiting',
              'createdAt': '2026-09-22T10:30:00.000',
              'estimatedWaitTime': 10,
              'isActive': true
            }
          }),
          201,
        );
      } else if (request.method == 'PATCH' && request.url.path.endsWith('/cancel')) {
        final pathSegments = request.url.pathSegments;
        final id = int.tryParse(pathSegments[pathSegments.length - 2]) ?? 99;
        
        return http.Response(
          jsonEncode({
            'queueToken': {
              'id': id,
              'serviceId': 1,
              'tokenNumber': 99,
              'status': 'cancelled',
              'createdAt': '2026-09-22T10:30:00.000',
              'estimatedWaitTime': 0,
              'isActive': false
            }
          }),
          200,
        );
      } else if (request.method == 'GET' && request.url.path.endsWith('/api/queue/active')) {
        return http.Response('Server Error', 500);
      } else if (request.method == 'GET' && request.url.path.endsWith('/api/services')) {
        return http.Response('Server Error', 500);
      }
      return http.Response('Not Found', 404);
    });

    final db = await DatabaseHelper.instance.database;
    await db.delete(DatabaseHelper.tableAppointments);
    await db.delete(DatabaseHelper.tableQueueTokens);
    await db.delete(DatabaseHelper.tableServices);
  });

  tearDown(() async {
    ApiService.globalTestClient = null;
  });

  testWidgets('Creating a token updates My Queue and handles duplicates', (WidgetTester tester) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(DatabaseHelper.tableServices);
    await db.insert(DatabaseHelper.tableServices, {
      'id': 1,
      'name': 'General Consultation',
      'description': 'Routine check-ups',
      'icon': 'consultation',
      'is_active': 1,
    });

    await tester.pumpWidget(const QueueLessApp(initialScreen: MainScreen()));
    await tester.pumpAndSettle();

    // Tap a service (from seeded db)
    final serviceText = find.text('General Consultation');
    expect(serviceText, findsOneWidget);
    await tester.ensureVisible(serviceText);
    await tester.pumpAndSettle();
    await tester.tap(serviceText);
    await tester.pumpAndSettle();

    // Tap Take a Token
    final takeTokenBtn = find.text('Take a Token');
    expect(takeTokenBtn, findsOneWidget);
    
    await tester.ensureVisible(takeTokenBtn);
    await tester.pumpAndSettle();
    
    await tester.tap(takeTokenBtn);
    await tester.pumpAndSettle();
    
    // The Navigator.push Future completes after the pop animation, which triggers
    // onNavigate(1). We need one more pump to let the tab switch render.
    await tester.pumpAndSettle();

    // The app should navigate to My Queue and show the token
    expect(find.text('My Queue'), findsWidgets);
    expect(find.text('TOKEN #1'), findsOneWidget);
    expect(find.text('WAITING'), findsOneWidget);

    // Navigate back to Home
    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle();

    // Tap the service again
    await tester.tap(serviceText);
    await tester.pumpAndSettle();

    // Tap Take a Token again
    await tester.tap(takeTokenBtn);
    await tester.pumpAndSettle();

    // Should pop back to My Queue
    expect(find.text('My Queue'), findsWidgets);
    
    // Verify no new token was created
    final dbHandle2 = await DatabaseHelper.instance.database;
    final allRaw2 = await dbHandle2.query(DatabaseHelper.tableQueueTokens);
    expect(allRaw2.length, 1);
  });

  testWidgets('Leaving a queue removes it from active list', (WidgetTester tester) async {
    // 1. Manually insert an active token
    final db = await DatabaseHelper.instance.database;
    await db.delete(DatabaseHelper.tableServices);
    await db.insert(DatabaseHelper.tableServices, {
      'id': 1,
      'name': 'General Consultation',
      'description': 'Routine check-ups',
      'icon': 'consultation',
      'is_active': 1,
    });

    final token = QueueToken(
      serviceId: 1, // seed data has id 1
      tokenNumber: 99,
      status: 'waiting',
      createdAt: DateTime.now(),
      estimatedWaitTime: 10,
      isActive: true,
    );
    await DatabaseHelper.instance.insertQueueToken(token);

    // 2. Load the app and navigate to My Queue tab
    await tester.pumpWidget(const QueueLessApp(initialScreen: MainScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(NavigationDestination, 'My Queue'));
    await tester.pumpAndSettle();

    // 3. Verify it's there
    expect(find.text('TOKEN #99'), findsOneWidget);
    
    // 4. Leave queue
    final leaveBtn = find.text('Leave Queue');
    expect(leaveBtn, findsOneWidget);
    await tester.tap(leaveBtn);
    await tester.pumpAndSettle();

    // 5. Verify it's gone and empty state shows
    expect(find.text('TOKEN #99'), findsNothing);
    expect(find.text('No Active Queue'), findsOneWidget);
  });
}
