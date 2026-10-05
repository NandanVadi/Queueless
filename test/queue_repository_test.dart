import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:queueless/repositories/queue_repository.dart';
import 'package:queueless/services/api_service.dart';
import 'package:queueless/database/database_helper.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    DatabaseHelper.instance.setDatabasePathForTesting(inMemoryDatabasePath);
    await DatabaseHelper.instance.database;
  });

  group('QueueRepository Tests', () {
    setUp(() async {
      final db = await DatabaseHelper.instance.database;
      await db.delete(DatabaseHelper.tableAppointments);
      await db.delete(DatabaseHelper.tableQueueTokens);
      await db.delete(DatabaseHelper.tableServices);
      
      // Seed a service
      await db.insert(DatabaseHelper.tableServices, {
        'id': 1,
        'name': 'Test Service',
        'description': 'Desc',
        'icon': 'test',
        'is_active': 1,
      });
    });

    test('createQueueToken API success -> token created and synced to SQLite', () async {
      final mockClient = MockClient((request) async {
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
      });

      final apiService = ApiService(client: mockClient);
      final repo = QueueRepository(apiService: apiService);

      final token = await repo.createQueueToken(1);

      expect(token.id, 1);
      expect(token.tokenNumber, 1);

      // Verify it was saved to SQLite
      final dbTokens = await DatabaseHelper.instance.getQueueTokens();
      expect(dbTokens.length, 1);
      expect(dbTokens.first.id, 1);
      expect(dbTokens.first.tokenNumber, 1);
    });

    test('createQueueToken API failure -> throws exception, NO local token created', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Server Error', 500);
      });

      final apiService = ApiService(client: mockClient);
      final repo = QueueRepository(apiService: apiService);

      expect(() => repo.createQueueToken(1), throwsException);

      // Verify nothing was saved to SQLite
      final dbTokens = await DatabaseHelper.instance.getQueueTokens();
      expect(dbTokens.isEmpty, true);
    });

    test('getActiveQueueTokens API success -> tokens returned and synced', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'queueTokens': [
              {
                'id': 2,
                'serviceId': 1,
                'tokenNumber': 5,
                'status': 'waiting',
                'createdAt': '2026-09-22T10:30:00.000',
                'estimatedWaitTime': 20,
                'isActive': true
              }
            ]
          }),
          200,
        );
      });

      final apiService = ApiService(client: mockClient);
      final repo = QueueRepository(apiService: apiService);

      final tokens = await repo.getActiveQueueTokens();

      expect(tokens.length, 1);
      expect(tokens.first.tokenNumber, 5);

      final dbTokens = await DatabaseHelper.instance.getQueueTokens();
      expect(dbTokens.length, 1);
      expect(dbTokens.first.id, 2);
    });

    test('getActiveQueueTokens API fails -> fallback to SQLite', () async {
      // Seed SQLite manually
      final db = await DatabaseHelper.instance.database;
      await db.insert(DatabaseHelper.tableQueueTokens, {
        'id': 3,
        'service_id': 1,
        'token_number': 8,
        'status': 'waiting',
        'created_at': '2026-09-22T10:30:00.000',
        'estimated_wait_time': 0,
        'is_active': 1,
      });

      final mockClient = MockClient((request) async {
        return http.Response('Server Error', 500);
      });

      final apiService = ApiService(client: mockClient);
      final repo = QueueRepository(apiService: apiService);

      final tokens = await repo.getActiveQueueTokens();

      expect(tokens.length, 1);
      expect(tokens.first.id, 3);
      expect(tokens.first.tokenNumber, 8);
    });

    test('cancelQueueToken API success -> token cancelled and synced', () async {
      // Seed SQLite manually
      final db = await DatabaseHelper.instance.database;
      await db.insert(DatabaseHelper.tableQueueTokens, {
        'id': 4,
        'service_id': 1,
        'token_number': 10,
        'status': 'waiting',
        'created_at': '2026-09-22T10:30:00.000',
        'estimated_wait_time': 0,
        'is_active': 1,
      });

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'queueToken': {
              'id': 4,
              'serviceId': 1,
              'tokenNumber': 10,
              'status': 'cancelled',
              'createdAt': '2026-09-22T10:30:00.000',
              'estimatedWaitTime': 0,
              'isActive': false
            }
          }),
          200,
        );
      });

      final apiService = ApiService(client: mockClient);
      final repo = QueueRepository(apiService: apiService);

      final token = await repo.cancelQueueToken(4);

      expect(token.status, 'cancelled');
      expect(token.isActive, false);

      final dbToken = await DatabaseHelper.instance.getQueueTokenById(4);
      expect(dbToken!.status, 'cancelled');
      expect(dbToken.isActive, false);
    });

    test('cancelQueueToken API failure -> throws exception, SQLite NOT updated', () async {
      // Seed SQLite manually
      final db = await DatabaseHelper.instance.database;
      await db.insert(DatabaseHelper.tableQueueTokens, {
        'id': 5,
        'service_id': 1,
        'token_number': 12,
        'status': 'waiting',
        'created_at': '2026-09-22T10:30:00.000',
        'estimated_wait_time': 0,
        'is_active': 1,
      });

      final mockClient = MockClient((request) async {
        return http.Response('Server Error', 500);
      });

      final apiService = ApiService(client: mockClient);
      final repo = QueueRepository(apiService: apiService);

      expect(() => repo.cancelQueueToken(5), throwsException);

      final dbToken = await DatabaseHelper.instance.getQueueTokenById(5);
      expect(dbToken!.status, 'waiting');
      expect(dbToken.isActive, true);
    });
  });
}
