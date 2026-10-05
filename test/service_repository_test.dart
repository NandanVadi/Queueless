import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:queueless/repositories/service_repository.dart';
import 'package:queueless/services/api_service.dart';
import 'package:queueless/database/database_helper.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    DatabaseHelper.instance.setDatabasePathForTesting(inMemoryDatabasePath);
    await DatabaseHelper.instance.database;
  });

  group('ServiceRepository Tests', () {
    setUp(() async {
      final db = await DatabaseHelper.instance.database;
      await db.delete(DatabaseHelper.tableAppointments);
      await db.delete(DatabaseHelper.tableQueueTokens);
      await db.delete(DatabaseHelper.tableServices);
    });

    test('API succeeds -> services returned and synchronized to SQLite', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'services': [
              {
                'id': 1,
                'name': 'API Service',
                'description': 'From API',
                'icon': 'test_icon',
                'isActive': true
              }
            ]
          }),
          200,
        );
      });

      final apiService = ApiService(client: mockClient);
      final repo = ServiceRepository(apiService: apiService);

      final services = await repo.getServices();

      expect(services.length, 1);
      expect(services.first.name, 'API Service');

      // Verify it was saved to SQLite
      final dbServices = await DatabaseHelper.instance.getServices();
      expect(dbServices.length, 1);
      expect(dbServices.first.name, 'API Service');
    });

    test('API fails -> cached SQLite services returned', () async {
      // Seed SQLite manually
      final db = await DatabaseHelper.instance.database;
      await db.insert(DatabaseHelper.tableServices, {
        'id': 1,
        'name': 'Cached Service',
        'description': 'From Cache',
        'icon': 'cache_icon',
        'is_active': 1,
      });

      final mockClient = MockClient((request) async {
        return http.Response('Server Error', 500);
      });

      final apiService = ApiService(client: mockClient);
      final repo = ServiceRepository(apiService: apiService);

      final services = await repo.getServices();

      expect(services.length, 1);
      expect(services.first.name, 'Cached Service');
    });

    test('API fails + SQLite empty -> appropriate fallback (empty list)', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Server Error', 500);
      });

      final apiService = ApiService(client: mockClient);
      final repo = ServiceRepository(apiService: apiService);

      final services = await repo.getServices();

      expect(services, isEmpty);
    });

    test('API returns malformed data -> fallback to SQLite works', () async {
      final db = await DatabaseHelper.instance.database;
      await db.insert(DatabaseHelper.tableServices, {
        'id': 1,
        'name': 'Fallback Service',
        'description': 'From Cache',
        'icon': 'cache_icon',
        'is_active': 1,
      });

      final mockClient = MockClient((request) async {
        return http.Response('not json', 200);
      });

      final apiService = ApiService(client: mockClient);
      final repo = ServiceRepository(apiService: apiService);

      final services = await repo.getServices();

      expect(services.length, 1);
      expect(services.first.name, 'Fallback Service');
    });

    test('Existing service IDs remain safe (Upsert works correctly)', () async {
      final db = await DatabaseHelper.instance.database;
      // Seed with ID 1
      await db.insert(DatabaseHelper.tableServices, {
        'id': 1,
        'name': 'Old Service',
        'description': 'Old Description',
        'icon': 'old_icon',
        'is_active': 1,
      });

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'services': [
              {
                'id': 1, // Same ID!
                'name': 'Updated Service',
                'description': 'New Description',
                'icon': 'new_icon',
                'isActive': true
              },
              {
                'id': 2,
                'name': 'New Service',
                'description': 'New Description',
                'icon': 'new_icon',
                'isActive': true
              }
            ]
          }),
          200,
        );
      });

      final apiService = ApiService(client: mockClient);
      final repo = ServiceRepository(apiService: apiService);

      final services = await repo.getServices();

      expect(services.length, 2);
      expect(services.firstWhere((s) => s.id == 1).name, 'Updated Service');

      // Verify in DB
      final dbServices = await DatabaseHelper.instance.getServices();
      expect(dbServices.length, 2);
      
      final dbService1 = dbServices.firstWhere((s) => s.id == 1);
      expect(dbService1.name, 'Updated Service');
    });

    test('Existing queue token references are not broken by upsert', () async {
      final db = await DatabaseHelper.instance.database;
      
      // 1. Insert Service (id 1)
      await db.insert(DatabaseHelper.tableServices, {
        'id': 1,
        'name': 'Original Service',
        'description': 'Desc',
        'icon': 'icon',
        'is_active': 1,
      });

      // 2. Insert Queue Token referencing Service ID 1
      await db.insert(DatabaseHelper.tableQueueTokens, {
        'service_id': 1,
        'token_number': 10,
        'status': 'waiting',
        'created_at': DateTime.now().toIso8601String(),
        'estimated_wait_time': 5,
        'is_active': 1,
      });

      // 3. Sync API which updates Service ID 1
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'services': [
              {
                'id': 1,
                'name': 'Updated Service API',
                'description': 'Desc',
                'icon': 'icon',
                'isActive': true
              }
            ]
          }),
          200,
        );
      });

      final apiService = ApiService(client: mockClient);
      final repo = ServiceRepository(apiService: apiService);

      await repo.getServices();

      // 4. Verify queue token still exists and points to updated service
      final tokens = await DatabaseHelper.instance.getQueueTokens();
      expect(tokens.length, 1);
      expect(tokens.first.serviceId, 1);
      expect(tokens.first.tokenNumber, 10);
      
      final updatedService = await DatabaseHelper.instance.getServiceById(1);
      expect(updatedService!.name, 'Updated Service API');
    });
  });
}
