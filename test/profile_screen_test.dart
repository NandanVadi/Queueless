import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:queueless/models/user.dart';
import 'package:queueless/services/api_service.dart';
import 'package:queueless/screens/profile_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createWidgetUnderTest() {
    return const MaterialApp(
      home: Scaffold(
        body: ProfileScreen(),
      ),
    );
  }

  testWidgets('ProfileScreen shows loading initially and then data', (tester) async {
    ApiService.authToken = 'fake-token';
    ApiService.globalTestClient = MockClient((request) async {
      await Future.delayed(const Duration(milliseconds: 50));
      return http.Response(
        jsonEncode({
          'user': {
            'id': 1,
            'name': 'John Doe',
            'email': 'john@test.com',
            'role': 'user',
            'createdAt': '2027-01-01T00:00:00.000Z'
          }
        }),
        200,
      );
    });

    await tester.pumpWidget(createWidgetUnderTest());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    
    await tester.pumpAndSettle();
    expect(find.text('John Doe'), findsOneWidget);
    expect(find.text('john@test.com'), findsOneWidget);
    expect(find.text('Customer'), findsOneWidget);
  });

  testWidgets('ProfileScreen edit and save updates name', (tester) async {
    ApiService.authToken = 'fake-token';
    
    int callCount = 0;
    ApiService.globalTestClient = MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response(
          jsonEncode({
            'user': {
              'id': 1,
              'name': 'John Doe',
              'email': 'john@test.com',
              'role': 'operator',
              'createdAt': '2027-01-01T00:00:00.000Z'
            }
          }),
          200,
        );
      } else if (request.method == 'PATCH') {
        callCount++;
        final body = jsonDecode(request.body);
        return http.Response(
          jsonEncode({
            'user': {
              'id': 1,
              'name': body['name'],
              'email': 'john@test.com',
              'role': 'operator',
              'createdAt': '2027-01-01T00:00:00.000Z'
            }
          }),
          200,
        );
      }
      return http.Response('', 404);
    });

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('Operator'), findsOneWidget);

    // Tap Edit Profile
    await tester.tap(find.text('Edit Profile'));
    await tester.pumpAndSettle();

    // Enter new name
    await tester.enterText(find.byType(TextField), 'John Smith');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(callCount, 1);
    expect(find.text('John Smith'), findsOneWidget);
    expect(find.text('Edit Profile'), findsOneWidget); // Back to read-only view
  });

  testWidgets('ProfileScreen logout clears token', (tester) async {
    ApiService.authToken = 'fake-token';
    ApiService.globalTestClient = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'user': {
            'id': 1,
            'name': 'John Doe',
            'email': 'john@test.com',
            'role': 'admin',
            'createdAt': '2027-01-01T00:00:00.000Z'
          }
        }),
        200,
      );
    });

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('Administrator'), findsOneWidget);

    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();

    expect(ApiService.authToken, isNull);
  });

  group('User Model Tests', () {
    test('User copyWith works properly', () {
      final user = User(
        id: 1,
        name: 'Original',
        email: 'test@test.com',
        role: 'user',
        createdAt: DateTime.now(),
      );

      final updated = user.copyWith(name: 'Updated');
      expect(updated.id, user.id);
      expect(updated.name, 'Updated');
      expect(updated.email, user.email);
    });
  });
}
