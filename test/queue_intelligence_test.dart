import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:convert';
import 'dart:async';

import 'package:queueless/database/database_helper.dart';
import 'package:queueless/services/api_service.dart';
import 'package:queueless/screens/my_queue_screen.dart';
import 'package:queueless/models/queue_token.dart';
import 'package:queueless/models/service.dart';

// Mocks
class MockClient extends http.BaseClient {
  bool failNextRequest = false;
  List<Map<String, dynamic>> mockQueueTokens = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (failNextRequest) {
      failNextRequest = false;
      return http.StreamedResponse(
        Stream.value(utf8.encode('Internal Server Error')),
        500,
      );
    }
    
    if (request.url.path.contains('/api/queue/active') && request.method == 'GET') {
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({'queueTokens': mockQueueTokens}))),
        200,
      );
    }

    if (request.url.path.contains('/api/queue/') && request.method == 'PATCH') {
      // simulate cancellation
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({
          'queueToken': mockQueueTokens.first..['status'] = 'cancelled'
        }))),
        200,
      );
    }

    return http.StreamedResponse(Stream.value(utf8.encode('{}')), 404);
  }
}

void main() {
  late MockClient mockClient;
  
  setUpAll(() async {
    WidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    SharedPreferences.setMockInitialValues({'queueless_auth_token': 'fake_jwt'});
    DatabaseHelper.instance.setDatabasePathForTesting(inMemoryDatabasePath);
  });
  
  setUp(() async {
    mockClient = MockClient();
    ApiService.globalTestClient = mockClient;
    ApiService.authToken = 'fake_jwt';
    
    // Create necessary seed service
    await DatabaseHelper.instance.database;
  });

  tearDown(() async {
    await DatabaseHelper.instance.closeDatabase();
  });
  
  testWidgets('Queue token parsing and displaying intelligence', (tester) async {
    // 1. queue summary parsing
    final jsonResponse = {
      'id': 1,
      'serviceId': 1,
      'tokenNumber': 42,
      'status': 'waiting',
      'createdAt': '2026-10-10T10:00:00.000Z',
      'estimatedWaitTime': 20,
      'isActive': true,
      'peopleAhead': 2,
      'currentTokenNumber': 40,
      'service': {
        'id': 1,
        'name': 'Banking',
        'description': 'Test',
        'icon': 'bank',
        'isActive': true,
      }
    };
    
    final token = QueueToken.fromJson(jsonResponse);
    expect(token.peopleAhead, 2);
    expect(token.currentTokenNumber, 40);
    expect(token.estimatedWaitTime, 20);
    
    // SQLite synchronization (7)
    await DatabaseHelper.instance.synchronizeQueueToken(token);
    final cached = await DatabaseHelper.instance.getQueueTokenById(1);
    expect(cached?.peopleAhead, 2);
    expect(cached?.currentTokenNumber, 40);

    // 2-5: displaying people ahead, estimated wait, token number, queue status
    mockClient.mockQueueTokens = [jsonResponse];

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: MyQueueScreen(isActive: true)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('TOKEN #42'), findsOneWidget);
    expect(find.text('WAITING'), findsOneWidget);
    expect(find.text('~20 min'), findsOneWidget);
    expect(find.text('People Ahead'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Current Token'), findsOneWidget);
    expect(find.text('#40'), findsOneWidget);
    
    // 10. Live socket indicator
    expect(find.text('Live Queue • Updating automatically'), findsOneWidget);
  });
  
  testWidgets('Empty queue state', (tester) async {
    // 8. empty queue
    mockClient.mockQueueTokens = [];
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: MyQueueScreen(isActive: true)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('No Active Queue'), findsOneWidget);
  });
  
  testWidgets('API failure fallback to SQLite', (tester) async {
    // 9. API failure fallback
    final token = QueueToken(
      id: 99, serviceId: 1, tokenNumber: 10, status: 'waiting', 
      createdAt: DateTime.now(), estimatedWaitTime: 50, isActive: true, 
      peopleAhead: 5, currentTokenNumber: 5, 
      service: const Service(id: 1, name: 'Bank', description: '', icon: 'bank')
    );
    await DatabaseHelper.instance.synchronizeQueueToken(token);
    
    mockClient.failNextRequest = true; // API will fail

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: MyQueueScreen(isActive: true)),
    ));
    await tester.pumpAndSettle();

    // It should load from SQLite cache instead
    expect(find.text('TOKEN #10'), findsOneWidget);
    expect(find.text('5'), findsOneWidget); // People ahead
  });
  
  testWidgets('Cancelled token behavior', (tester) async {
    // 11. cancelled token behavior
    final jsonResponse = {
      'id': 1, 'serviceId': 1, 'tokenNumber': 1, 'status': 'cancelled',
      'createdAt': '2026-10-10T10:00:00.000Z', 'estimatedWaitTime': 0, 'isActive': false,
      'service': {'id': 1, 'name': 'Bank', 'description': 'T', 'icon': 'bank', 'isActive': true}
    };
    mockClient.mockQueueTokens = [jsonResponse];

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: MyQueueScreen(isActive: true)),
    ));
    await tester.pumpAndSettle();
    
    // Inactive tokens don't display people ahead or current token
    expect(find.text('People Ahead'), findsNothing);
    expect(find.text('CANCELLED'), findsNWidgets(2));
  });
}
