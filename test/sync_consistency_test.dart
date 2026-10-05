import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:queueless/database/database_helper.dart';
import 'package:queueless/models/appointment.dart';
import 'package:queueless/models/queue_token.dart';
import 'package:queueless/repositories/appointment_repository.dart';
import 'package:queueless/repositories/queue_repository.dart';
import 'package:queueless/services/api_service.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    DatabaseHelper.instance.setDatabasePathForTesting(inMemoryDatabasePath);
    await DatabaseHelper.instance.database;
  });

  setUp(() async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(DatabaseHelper.tableAppointments);
    await db.delete(DatabaseHelper.tableQueueTokens);
    await db.delete(DatabaseHelper.tableServices);
  });

  const service = {
    'id': 9,
    'name': 'Server Banking',
    'description': 'Authoritative service record',
    'icon': 'bank',
    'isActive': true,
  };

  Map<String, dynamic> token({
    required int id,
    required int number,
    bool active = true,
    String status = 'waiting',
  }) => {
    'id': id,
    'serviceId': 9,
    'tokenNumber': number,
    'status': status,
    'createdAt': '2026-09-28T10:30:00.000Z',
    'estimatedWaitTime': 10,
    'isActive': active,
    'service': service,
  };

  Map<String, dynamic> appointment({
    required int id,
    String status = 'scheduled',
  }) => {
    'id': id,
    'serviceId': 9,
    'customerName': 'Asha',
    'appointmentDate': '2026-10-15',
    'appointmentTime': '10:30',
    'status': status,
    'createdAt': '2026-09-28T10:30:00.000Z',
    'service': service,
  };

  test(
    'queue snapshot upserts safely and makes missing active cache rows stale',
    () async {
      await DatabaseHelper.instance.synchronizeQueueToken(
        QueueToken.fromJson(token(id: 1, number: 1)),
      );
      await DatabaseHelper.instance.synchronizeQueueToken(
        QueueToken.fromJson(token(id: 2, number: 2)),
      );

      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'queueTokens': [token(id: 1, number: 7)],
          }),
          200,
        ),
      );
      final repository = QueueRepository(
        apiService: ApiService(client: client),
      );

      final remote = await repository.getActiveQueueTokens();
      expect(remote.single.tokenNumber, 7);
      expect((await DatabaseHelper.instance.getServices()).single.id, 9);
      expect((await DatabaseHelper.instance.getQueueTokens()), hasLength(2));
      expect(
        (await DatabaseHelper.instance.getQueueTokenById(1))!.tokenNumber,
        7,
      );
      expect(
        (await DatabaseHelper.instance.getQueueTokenById(2))!.isActive,
        isFalse,
      );
      expect(
        await DatabaseHelper.instance.getActiveQueueTokens(),
        hasLength(1),
      );
    },
  );

  test('queue API failure reads the last synchronized cache', () async {
    await DatabaseHelper.instance.synchronizeQueueToken(
      QueueToken.fromJson(token(id: 3, number: 3)),
    );
    final repository = QueueRepository(
      apiService: ApiService(
        client: MockClient((_) async => http.Response('', 500)),
      ),
    );

    expect((await repository.getActiveQueueTokens()).single.id, 3);
  });

  test(
    'a child without an included or cached parent is rejected safely',
    () async {
      final childWithoutService = QueueToken(
        id: 4,
        serviceId: 99,
        tokenNumber: 1,
        status: 'waiting',
        createdAt: DateTime(2026, 9, 28),
      );

      await expectLater(
        DatabaseHelper.instance.synchronizeQueueToken(childWithoutService),
        throwsA(isA<StateError>()),
      );
      expect(await DatabaseHelper.instance.getQueueTokenById(4), isNull);
    },
  );

  test(
    'appointment snapshot upserts and removes an orphaned stale cache row',
    () async {
      await DatabaseHelper.instance.synchronizeAppointment(
        Appointment.fromJson(appointment(id: 10)),
      );
      await DatabaseHelper.instance.synchronizeAppointment(
        Appointment.fromJson(appointment(id: 11)),
      );
      final repository = AppointmentRepository(
        apiService: ApiService(
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'appointments': [appointment(id: 10)],
              }),
              200,
            ),
          ),
        ),
      );

      expect(await repository.getAppointments(), hasLength(1));
      expect(await DatabaseHelper.instance.getAppointmentById(10), isNotNull);
      expect(await DatabaseHelper.instance.getAppointmentById(11), isNull);
    },
  );

  test(
    'cancellation is only cached after the server acknowledges it',
    () async {
      await DatabaseHelper.instance.synchronizeAppointment(
        Appointment.fromJson(appointment(id: 12)),
      );
      final repository = AppointmentRepository(
        apiService: ApiService(
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'appointment': appointment(id: 12, status: 'cancelled'),
              }),
              200,
            ),
          ),
        ),
      );

      expect((await repository.cancelAppointment(12)).status, 'cancelled');
      expect(
        (await DatabaseHelper.instance.getAppointmentById(12))!.status,
        'cancelled',
      );
    },
  );
}
