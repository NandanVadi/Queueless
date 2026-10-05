import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:queueless/database/database_helper.dart';
import 'package:queueless/models/queue_token.dart';
import 'package:queueless/models/appointment.dart';
import 'package:queueless/models/service.dart';
import 'package:queueless/widgets/queue_token_card.dart';
import 'package:queueless/widgets/appointment_card.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    DatabaseHelper.instance.setDatabasePathForTesting(inMemoryDatabasePath);
    await DatabaseHelper.instance.database;
  });

  group('Database Verification for QR Scanning', () {
    setUp(() async {
      final db = await DatabaseHelper.instance.database;
      await db.delete(DatabaseHelper.tableAppointments);
      await db.delete(DatabaseHelper.tableQueueTokens);
      await db.delete(DatabaseHelper.tableServices);
      
      // Seed service
      await db.insert(
        DatabaseHelper.tableServices,
        {
          'id': 1,
          'name': 'Test Service',
          'description': 'Description',
          'icon': 'test',
          'is_active': 1,
        },
      );
    });

    test('Existing queue token can be looked up by ID', () async {
      final token = QueueToken(
        serviceId: 1,
        tokenNumber: 5,
        status: 'waiting',
        createdAt: DateTime.now(),
        estimatedWaitTime: 10,
        isActive: true,
      );
      final id = await DatabaseHelper.instance.insertQueueToken(token);

      final fetchedToken = await DatabaseHelper.instance.getQueueTokenById(id);
      expect(fetchedToken, isNotNull);
      expect(fetchedToken!.tokenNumber, 5);
      expect(fetchedToken.status, 'waiting');
    });

    test('Existing appointment can be looked up by ID', () async {
      final appointment = Appointment(
        serviceId: 1,
        customerName: 'Test Name',
        appointmentDate: '2026-10-01',
        appointmentTime: '10:00',
        status: 'scheduled',
        createdAt: DateTime.now(),
      );
      final id = await DatabaseHelper.instance.insertAppointment(appointment);

      final fetchedAppt = await DatabaseHelper.instance.getAppointmentById(id);
      expect(fetchedAppt, isNotNull);
      expect(fetchedAppt!.customerName, 'Test Name');
      expect(fetchedAppt.status, 'scheduled');
    });

    test('Cancelled/inactive queue token is correctly identified', () async {
      final token = QueueToken(
        serviceId: 1,
        tokenNumber: 6,
        status: 'cancelled',
        createdAt: DateTime.now(),
        estimatedWaitTime: 0,
        isActive: false,
      );
      final id = await DatabaseHelper.instance.insertQueueToken(token);

      final fetchedToken = await DatabaseHelper.instance.getQueueTokenById(id);
      expect(fetchedToken, isNotNull);
      expect(fetchedToken!.isActive, false);
      expect(fetchedToken.status, 'cancelled');
    });

    test('Cancelled appointment is correctly identified', () async {
      final appointment = Appointment(
        serviceId: 1,
        customerName: 'Test Cancelled',
        appointmentDate: '2026-10-01',
        appointmentTime: '10:00',
        status: 'cancelled',
        createdAt: DateTime.now(),
      );
      final id = await DatabaseHelper.instance.insertAppointment(appointment);

      final fetchedAppt = await DatabaseHelper.instance.getAppointmentById(id);
      expect(fetchedAppt, isNotNull);
      expect(fetchedAppt!.status, 'cancelled');
    });

    test('Non-existent record is rejected (returns null)', () async {
      final fetchedToken = await DatabaseHelper.instance.getQueueTokenById(999);
      expect(fetchedToken, isNull);

      final fetchedAppt = await DatabaseHelper.instance.getAppointmentById(999);
      expect(fetchedAppt, isNull);
    });
  });

  group('UI Tests: QR Integration', () {
    testWidgets('Show QR action is available for an active queue token', (WidgetTester tester) async {
      final service = const Service(
        id: 1,
        name: 'Test Service',
        description: 'Test',
        icon: 'test',
        isActive: true,
      );

      final token = QueueToken(
        id: 1,
        serviceId: 1,
        tokenNumber: 5,
        status: 'waiting',
        createdAt: DateTime.now(),
        estimatedWaitTime: 10,
        isActive: true,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: QueueTokenCard(
            token: token,
            service: service,
            onLeave: () {},
          ),
        ),
      ));

      expect(find.text('Show QR'), findsOneWidget);
      expect(find.text('Leave Queue'), findsOneWidget);
    });

    testWidgets('Show QR action is NOT available for an inactive queue token', (WidgetTester tester) async {
      final service = const Service(
        id: 1,
        name: 'Test Service',
        description: 'Test',
        icon: 'test',
        isActive: true,
      );

      final token = QueueToken(
        id: 1,
        serviceId: 1,
        tokenNumber: 5,
        status: 'cancelled',
        createdAt: DateTime.now(),
        estimatedWaitTime: 0,
        isActive: false,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: QueueTokenCard(
            token: token,
            service: service,
            onLeave: () {},
          ),
        ),
      ));

      expect(find.text('Show QR'), findsNothing);
      expect(find.text('CANCELLED'), findsNWidgets(2));
    });

    testWidgets('Show QR action is available for an active appointment', (WidgetTester tester) async {
      final appointment = Appointment(
        id: 1,
        serviceId: 1,
        customerName: 'Test Name',
        appointmentDate: '2026-10-01',
        appointmentTime: '10:00',
        status: 'scheduled',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AppointmentCard(
            appointment: appointment,
            serviceName: 'Test Service',
            onCancel: () {},
          ),
        ),
      ));

      expect(find.text('Show QR'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('Show QR action is NOT available for a cancelled appointment', (WidgetTester tester) async {
      final appointment = Appointment(
        id: 1,
        serviceId: 1,
        customerName: 'Test Name',
        appointmentDate: '2026-10-01',
        appointmentTime: '10:00',
        status: 'cancelled',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AppointmentCard(
            appointment: appointment,
            serviceName: 'Test Service',
            onCancel: () {},
          ),
        ),
      ));

      expect(find.text('Show QR'), findsNothing);
    });
  });
}
