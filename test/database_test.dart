import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:queueless/database/database_helper.dart';
import 'package:queueless/models/service.dart';
import 'package:queueless/models/queue_token.dart';
import 'package:queueless/models/appointment.dart';

/// Database integration tests for QueueLess Milestone 3.
///
/// These tests use [sqflite_common_ffi] so they run entirely on the Dart VM
/// without a real device or emulator — the same SQLite engine is used, just
/// loaded via FFI instead of the platform channel.
///
/// Each test group uses [setUp] + [tearDown] to open a fresh in-memory
/// database and close it afterwards, preventing state from leaking between
/// tests and ensuring the production database on a real device is never
/// touched.
void main() {
  // ── Test environment setup ────────────────────────────────────────────────

  /// Initialise sqflite to use the FFI implementation (Dart VM / desktop).
  /// This must run once before any database code executes.
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    DatabaseHelper.instance.setDatabasePathForTesting(inMemoryDatabasePath);
    // Initialize once
    await DatabaseHelper.instance.database;
  });

  setUp(() async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(DatabaseHelper.tableAppointments);
    await db.delete(DatabaseHelper.tableQueueTokens);
    await db.delete(DatabaseHelper.tableServices);
  });

  tearDown(() async {
    // Do nothing, keep DB alive
  });

  // ══════════════════════════════════════════════════════════════════════════
  // SERVICE CRUD TESTS
  // ══════════════════════════════════════════════════════════════════════════

  group('Service CRUD', () {
    // Helper — creates a sample Service without an id.
    Service makeService({String name = 'Banking'}) => Service(
          name: name,
          description: 'Counter and account services',
          icon: 'bank',
          isActive: true,
        );

    // ── INSERT ──────────────────────────────────────────────────────────────

    test('insert returns a positive SQLite-generated ID', () async {
      final id = await DatabaseHelper.instance.insertService(makeService());

      // SQLite AUTOINCREMENT starts at 1.
      expect(id, greaterThan(0));
    });

    test('insert with includeId:false does not pre-set the id', () async {
      final service = makeService();
      // Confirm the Dart object has no id before inserting.
      expect(service.id, isNull);

      final generatedId =
          await DatabaseHelper.instance.insertService(service);
      expect(generatedId, greaterThan(0));
    });

    // ── READ ────────────────────────────────────────────────────────────────

    test('getServices returns inserted service with correct field values',
        () async {
      await DatabaseHelper.instance.insertService(makeService());

      final services = await DatabaseHelper.instance.getServices();

      expect(services, hasLength(1));
      expect(services.first.name, 'Banking');
      expect(services.first.description, 'Counter and account services');
      expect(services.first.icon, 'bank');
    });

    test('getServices returns multiple services', () async {
      await DatabaseHelper.instance.insertService(makeService(name: 'Alpha'));
      await DatabaseHelper.instance.insertService(makeService(name: 'Beta'));

      final services = await DatabaseHelper.instance.getServices();
      expect(services, hasLength(2));
    });

    // ── BOOLEAN MAPPING ─────────────────────────────────────────────────────

    test('bool isActive=true is stored as INTEGER 1 and read back as true',
        () async {
      final id = await DatabaseHelper.instance
          .insertService(makeService()); // isActive defaults true
      final service =
          (await DatabaseHelper.instance.getServices()).first;

      expect(service.isActive, isTrue);
      // Verify the raw row to confirm the INTEGER value in SQLite.
      final db = await DatabaseHelper.instance.database;
      final raw = await db.query('services', where: 'id = ?', whereArgs: [id]);
      expect(raw.first['is_active'], 1);
    });

    test('bool isActive=false is stored as INTEGER 0 and read back as false',
        () async {
      final svc = Service(
        name: 'Inactive Service',
        description: 'desc',
        icon: 'icon',
        isActive: false,
      );
      final id = await DatabaseHelper.instance.insertService(svc);

      final db = await DatabaseHelper.instance.database;
      final raw = await db.query('services', where: 'id = ?', whereArgs: [id]);
      expect(raw.first['is_active'], 0);

      final services = await DatabaseHelper.instance.getServices();
      expect(services.first.isActive, isFalse);
    });

    // ── toMap / fromMap round-trip ───────────────────────────────────────────

    test('toMap / fromMap round-trip preserves all fields', () {
      const original = Service(
        id: 42,
        name: 'Healthcare',
        description: 'OPD clinics',
        icon: 'hospital',
        isActive: true,
      );
      final map = original.toMap();
      final restored = Service.fromMap(map);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.description, original.description);
      expect(restored.icon, original.icon);
      expect(restored.isActive, original.isActive);
    });

    test('toMap with includeId:false excludes the id key', () {
      const svc = Service(id: 5, name: 'n', description: 'd', icon: 'i');
      final map = svc.toMap(includeId: false);
      expect(map.containsKey('id'), isFalse);
    });

    // ── UPDATE ──────────────────────────────────────────────────────────────

    test('updateService modifies the correct row and rowsAffected == 1',
        () async {
      final id =
          await DatabaseHelper.instance.insertService(makeService());

      final inserted =
          (await DatabaseHelper.instance.getServices()).first;
      final updated = inserted.copyWith(name: 'Banking Updated', isActive: false);

      final rowsAffected =
          await DatabaseHelper.instance.updateService(updated);
      expect(rowsAffected, 1);

      final services = await DatabaseHelper.instance.getServices();
      expect(services.first.name, 'Banking Updated');
      expect(services.first.isActive, isFalse);
      expect(services.first.id, id); // same row
    });

    // ── DELETE ──────────────────────────────────────────────────────────────

    test('deleteService removes the row and rowsAffected == 1', () async {
      final id =
          await DatabaseHelper.instance.insertService(makeService());

      final rowsAffected =
          await DatabaseHelper.instance.deleteService(id);
      expect(rowsAffected, 1);

      final services = await DatabaseHelper.instance.getServices();
      expect(services, isEmpty);
    });

    test('deleteService with non-existent id returns 0', () async {
      final rowsAffected =
          await DatabaseHelper.instance.deleteService(9999);
      expect(rowsAffected, 0);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // QUEUE TOKEN CRUD TESTS
  // ══════════════════════════════════════════════════════════════════════════

  group('QueueToken CRUD', () {
    /// Insert a parent Service first (required for the foreign key).
    Future<int> insertParentService() async {
      return DatabaseHelper.instance.insertService(const Service(
        name: 'Banking',
        description: 'desc',
        icon: 'bank',
      ));
    }

    QueueToken makeToken(int serviceId) => QueueToken(
          serviceId: serviceId,
          tokenNumber: 101,
          status: 'waiting',
          createdAt: DateTime(2026, 9, 22, 10, 30),
          estimatedWaitTime: 15,
          isActive: true,
        );

    // ── INSERT ──────────────────────────────────────────────────────────────

    test('insertQueueToken returns a positive SQLite-generated ID', () async {
      final serviceId = await insertParentService();
      final id = await DatabaseHelper.instance
          .insertQueueToken(makeToken(serviceId));

      expect(id, greaterThan(0));
    });

    // ── READ ────────────────────────────────────────────────────────────────

    test('getQueueTokens returns inserted token with correct field values',
        () async {
      final serviceId = await insertParentService();
      await DatabaseHelper.instance.insertQueueToken(makeToken(serviceId));

      final tokens = await DatabaseHelper.instance.getQueueTokens();

      expect(tokens, hasLength(1));
      expect(tokens.first.serviceId, serviceId);
      expect(tokens.first.tokenNumber, 101);
      expect(tokens.first.status, 'waiting');
      expect(tokens.first.estimatedWaitTime, 15);
      expect(tokens.first.isActive, isTrue);
    });

    // ── DATETIME SERIALISATION ───────────────────────────────────────────────

    test('createdAt DateTime is stored as ISO-8601 TEXT and round-trips correctly',
        () async {
      final serviceId = await insertParentService();
      final original = DateTime(2026, 9, 22, 10, 30, 0);
      final token = QueueToken(
        serviceId: serviceId,
        tokenNumber: 1,
        status: 'waiting',
        createdAt: original,
        estimatedWaitTime: 0,
      );

      final id = await DatabaseHelper.instance.insertQueueToken(token);

      // Verify raw TEXT value in the database.
      final db = await DatabaseHelper.instance.database;
      final raw = await db
          .query('queue_tokens', where: 'id = ?', whereArgs: [id]);
      final rawCreatedAt = raw.first['created_at'] as String;
      expect(rawCreatedAt, contains('2026-09-22')); // ISO-8601 format

      // Verify the round-trip from fromMap.
      final tokens = await DatabaseHelper.instance.getQueueTokens();
      expect(tokens.first.createdAt.year, original.year);
      expect(tokens.first.createdAt.month, original.month);
      expect(tokens.first.createdAt.day, original.day);
      expect(tokens.first.createdAt.hour, original.hour);
      expect(tokens.first.createdAt.minute, original.minute);
    });

    // ── toMap / fromMap round-trip ───────────────────────────────────────────

    test('QueueToken toMap / fromMap round-trip preserves all fields', () {
      final now = DateTime(2026, 9, 22, 12, 0);
      final original = QueueToken(
        id: 7,
        serviceId: 2,
        tokenNumber: 55,
        status: 'serving',
        createdAt: now,
        estimatedWaitTime: 5,
        isActive: false,
      );
      final restored = QueueToken.fromMap(original.toMap());

      expect(restored.id, original.id);
      expect(restored.serviceId, original.serviceId);
      expect(restored.tokenNumber, original.tokenNumber);
      expect(restored.status, original.status);
      expect(restored.estimatedWaitTime, original.estimatedWaitTime);
      expect(restored.isActive, original.isActive);
      expect(restored.createdAt.toIso8601String(),
          original.createdAt.toIso8601String());
    });

    // ── UPDATE ──────────────────────────────────────────────────────────────

    test('updateQueueToken modifies the correct row', () async {
      final serviceId = await insertParentService();
      await DatabaseHelper.instance.insertQueueToken(makeToken(serviceId));

      final token = (await DatabaseHelper.instance.getQueueTokens()).first;
      final updated =
          token.copyWith(status: 'serving', estimatedWaitTime: 5);

      final rowsAffected =
          await DatabaseHelper.instance.updateQueueToken(updated);
      expect(rowsAffected, 1);

      final tokens = await DatabaseHelper.instance.getQueueTokens();
      expect(tokens.first.status, 'serving');
      expect(tokens.first.estimatedWaitTime, 5);
    });

    // ── DELETE ──────────────────────────────────────────────────────────────

    test('deleteQueueToken removes the row', () async {
      final serviceId = await insertParentService();
      final id = await DatabaseHelper.instance
          .insertQueueToken(makeToken(serviceId));

      final rowsAffected =
          await DatabaseHelper.instance.deleteQueueToken(id);
      expect(rowsAffected, 1);

      expect(await DatabaseHelper.instance.getQueueTokens(), isEmpty);
    });

    // ── MILESTONE 5 EXTENSIONS ──────────────────────────────────────────────

    test('getNextTokenNumber returns correct sequential numbers', () async {
      final service1 = await insertParentService();
      final service2 = await DatabaseHelper.instance.insertService(const Service(
        name: 'Docs', description: 'desc', icon: 'doc',
      ));

      expect(await DatabaseHelper.instance.getNextTokenNumber(service1), 1);
      
      await DatabaseHelper.instance.insertQueueToken(makeToken(service1).copyWith(tokenNumber: 1));
      expect(await DatabaseHelper.instance.getNextTokenNumber(service1), 2);
      
      // Service 2 should have its own sequence
      expect(await DatabaseHelper.instance.getNextTokenNumber(service2), 1);
    });

    test('getActiveQueueTokenForService returns token only if active', () async {
      final serviceId = await insertParentService();
      
      expect(await DatabaseHelper.instance.getActiveQueueTokenForService(serviceId), isNull);
      
      final token = makeToken(serviceId).copyWith(isActive: false, status: 'cancelled');
      await DatabaseHelper.instance.insertQueueToken(token);
      
      // Should still be null because it's not active
      expect(await DatabaseHelper.instance.getActiveQueueTokenForService(serviceId), isNull);
      
      final activeToken = makeToken(serviceId).copyWith(isActive: true, status: 'waiting');
      await DatabaseHelper.instance.insertQueueToken(activeToken);
      
      final result = await DatabaseHelper.instance.getActiveQueueTokenForService(serviceId);
      expect(result, isNotNull);
      expect(result!.isActive, true);
    });

    test('getActiveQueueTokens returns all active tokens', () async {
      final serviceId = await insertParentService();
      
      await DatabaseHelper.instance.insertQueueToken(makeToken(serviceId).copyWith(isActive: false));
      await DatabaseHelper.instance.insertQueueToken(makeToken(serviceId).copyWith(isActive: true, tokenNumber: 2));
      
      final activeTokens = await DatabaseHelper.instance.getActiveQueueTokens();
      expect(activeTokens, hasLength(1));
      expect(activeTokens.first.tokenNumber, 2);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // APPOINTMENT CRUD TESTS
  // ══════════════════════════════════════════════════════════════════════════

  group('Appointment CRUD', () {
    Future<int> insertParentService() async {
      return DatabaseHelper.instance.insertService(const Service(
        name: 'Healthcare',
        description: 'OPD',
        icon: 'hospital',
      ));
    }

    Appointment makeAppointment(int serviceId) => Appointment(
          serviceId: serviceId,
          customerName: 'Nandan Vadi',
          appointmentDate: '2026-09-25',
          appointmentTime: '10:30',
          status: 'pending',
          createdAt: DateTime(2026, 9, 22, 9, 0),
        );

    // ── INSERT ──────────────────────────────────────────────────────────────

    test('insertAppointment returns a positive SQLite-generated ID', () async {
      final serviceId = await insertParentService();
      final id = await DatabaseHelper.instance
          .insertAppointment(makeAppointment(serviceId));

      expect(id, greaterThan(0));
    });

    // ── READ ────────────────────────────────────────────────────────────────

    test('getAppointments returns inserted appointment with correct values',
        () async {
      final serviceId = await insertParentService();
      await DatabaseHelper.instance
          .insertAppointment(makeAppointment(serviceId));

      final appointments = await DatabaseHelper.instance.getAppointments();

      expect(appointments, hasLength(1));
      expect(appointments.first.customerName, 'Nandan Vadi');
      expect(appointments.first.appointmentDate, '2026-09-25');
      expect(appointments.first.appointmentTime, '10:30');
      expect(appointments.first.status, 'pending');
    });

    // ── DATETIME SERIALISATION ───────────────────────────────────────────────

    test('Appointment createdAt round-trips correctly through SQLite', () async {
      final serviceId = await insertParentService();
      final original = DateTime(2026, 9, 22, 9, 0, 0);
      await DatabaseHelper.instance.insertAppointment(
        Appointment(
          serviceId: serviceId,
          customerName: 'Test',
          appointmentDate: '2026-10-01',
          appointmentTime: '09:00',
          status: 'confirmed',
          createdAt: original,
        ),
      );

      final appointments = await DatabaseHelper.instance.getAppointments();
      final restored = appointments.first.createdAt;
      expect(restored.year, original.year);
      expect(restored.month, original.month);
      expect(restored.day, original.day);
      expect(restored.hour, original.hour);
    });

    // ── toMap / fromMap round-trip ───────────────────────────────────────────

    test('Appointment toMap / fromMap round-trip preserves all fields', () {
      final now = DateTime(2026, 9, 22, 8, 0);
      final original = Appointment(
        id: 3,
        serviceId: 1,
        customerName: 'Alice',
        appointmentDate: '2026-10-05',
        appointmentTime: '14:00',
        status: 'confirmed',
        createdAt: now,
      );
      final restored = Appointment.fromMap(original.toMap());

      expect(restored.id, original.id);
      expect(restored.serviceId, original.serviceId);
      expect(restored.customerName, original.customerName);
      expect(restored.appointmentDate, original.appointmentDate);
      expect(restored.appointmentTime, original.appointmentTime);
      expect(restored.status, original.status);
      expect(restored.createdAt.toIso8601String(),
          original.createdAt.toIso8601String());
    });

    test('toMap with includeId:false excludes the id key', () {
      final appt = Appointment(
        id: 10,
        serviceId: 1,
        customerName: 'Bob',
        appointmentDate: '2026-10-01',
        appointmentTime: '11:00',
        status: 'pending',
        createdAt: DateTime.now(),
      );
      final map = appt.toMap(includeId: false);
      expect(map.containsKey('id'), isFalse);
    });

    // ── UPDATE ──────────────────────────────────────────────────────────────

    test('updateAppointment modifies the correct row', () async {
      final serviceId = await insertParentService();
      await DatabaseHelper.instance
          .insertAppointment(makeAppointment(serviceId));

      final appt =
          (await DatabaseHelper.instance.getAppointments()).first;
      final updated = appt.copyWith(status: 'confirmed');

      final rowsAffected =
          await DatabaseHelper.instance.updateAppointment(updated);
      expect(rowsAffected, 1);

      final appointments = await DatabaseHelper.instance.getAppointments();
      expect(appointments.first.status, 'confirmed');
    });

    // ── DELETE ──────────────────────────────────────────────────────────────

    test('deleteAppointment removes the row', () async {
      final serviceId = await insertParentService();
      final id = await DatabaseHelper.instance
          .insertAppointment(makeAppointment(serviceId));

      final rowsAffected =
          await DatabaseHelper.instance.deleteAppointment(id);
      expect(rowsAffected, 1);

      expect(await DatabaseHelper.instance.getAppointments(), isEmpty);
    });

    test('deleteAppointment with non-existent id returns 0', () async {
      final rowsAffected =
          await DatabaseHelper.instance.deleteAppointment(9999);
      expect(rowsAffected, 0);
    });
  });
}
