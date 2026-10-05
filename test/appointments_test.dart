import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:queueless/database/database_helper.dart';
import 'package:queueless/models/service.dart';
import 'package:queueless/models/appointment.dart';
import 'package:queueless/screens/appointments_screen.dart';
import 'package:queueless/screens/appointment_form_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:queueless/services/api_service.dart';
import 'dart:convert';

void main() {
  // Use FFI for SQLite in tests to prevent cross-isolate hangs (Lab 8 setup)
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    DatabaseHelper.instance.setDatabasePathForTesting(inMemoryDatabasePath);
    await DatabaseHelper.instance.database;
  });

  group('Database Tests: Appointments', () {
    setUp(() async {
      final db = await DatabaseHelper.instance.database;
      await db.delete(DatabaseHelper.tableAppointments);
      await db.delete(DatabaseHelper.tableQueueTokens);
      await db.delete(DatabaseHelper.tableServices);
    });

    test('Insert, Retrieve, Update, Cancel Appointment', () async {
      final appointment = Appointment(
        serviceId: 1,
        customerName: 'Test User',
        appointmentDate: '2026-10-01',
        appointmentTime: '10:00',
        status: 'scheduled',
        createdAt: DateTime.now(),
      );

      final id = await DatabaseHelper.instance.insertAppointment(appointment);
      expect(id, isPositive);

      final appointments = await DatabaseHelper.instance.getAppointments();
      expect(appointments.length, 1);
      expect(appointments.first.customerName, 'Test User');
      expect(appointments.first.status, 'scheduled');
      expect(appointments.first.serviceId, 1);

      // Cancel the appointment
      final cancelledAppointment = appointments.first.copyWith(
        status: 'cancelled',
      );
      final rowsAffected = await DatabaseHelper.instance.updateAppointment(
        cancelledAppointment,
      );
      expect(rowsAffected, 1);

      // Verify it was updated, not deleted
      final updatedAppointments = await DatabaseHelper.instance
          .getAppointments();
      expect(updatedAppointments.length, 1);
      expect(updatedAppointments.first.status, 'cancelled');
    });
  });

  group('UI Tests: Appointment Form & Screen', () {
    setUp(() async {
      ApiService.globalTestClient = MockClient((request) async {
        if (request.method == 'POST' &&
            request.url.path.endsWith('/api/appointments')) {
          final body = jsonDecode(request.body);
          return http.Response(
            jsonEncode({
              'appointment': {
                'id': 1,
                'serviceId': body['serviceId'],
                'customerName': body['customerName'],
                'appointmentDate': body['appointmentDate'],
                'appointmentTime': body['appointmentTime'],
                'status': 'scheduled',
                'createdAt': '2026-09-22T10:30:00.000',
                'service': {
                  'id': body['serviceId'],
                  'name': 'General Consultation',
                  'description': 'Test',
                  'icon': 'consultation',
                  'isActive': true,
                },
              },
            }),
            201,
          );
        } else if (request.method == 'PATCH' &&
            request.url.path.endsWith('/cancel')) {
          final pathSegments = request.url.pathSegments;
          final id = int.tryParse(pathSegments[pathSegments.length - 2]) ?? 1;
          return http.Response(
            jsonEncode({
              'appointment': {
                'id': id,
                'serviceId': 1,
                'customerName': 'Jane Smith',
                'appointmentDate': '2026-10-05',
                'appointmentTime': '14:30',
                'status': 'cancelled',
                'createdAt': '2026-09-22T10:30:00.000',
              },
            }),
            200,
          );
        } else if (request.method == 'GET' &&
            request.url.path.endsWith('/api/appointments')) {
          return http.Response('Server Error', 500);
        } else if (request.method == 'GET' &&
            request.url.path.endsWith('/api/services')) {
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

    testWidgets('Appointment form validates and submits', (
      WidgetTester tester,
    ) async {
      final service = const Service(
        id: 1,
        name: 'General Consultation',
        description: 'Test',
        icon: 'test',
        isActive: true,
      );

      await tester.pumpWidget(
        MaterialApp(home: AppointmentFormScreen(service: service)),
      );
      await tester.pumpAndSettle();

      // Tap Confirm without entering name
      await tester.tap(find.text('Confirm Appointment'));
      await tester.pumpAndSettle();

      // Expect validation error for name
      expect(find.text('Customer name is required'), findsOneWidget);

      // Enter name
      await tester.enterText(find.byType(TextFormField).last, 'John Doe');
      await tester.pumpAndSettle();

      // Tap Confirm without selecting date/time
      await tester.tap(find.text('Confirm Appointment'));
      await tester.pumpAndSettle();

      // Since the SnackBar might have passed, we just check if it didn't pop
      expect(find.text('Confirm Appointment'), findsOneWidget);

      // Tap select date
      await tester.tap(find.text('Select Date'));
      await tester.pumpAndSettle();

      // Select OK on DatePicker
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Tap select time
      await tester.tap(find.text('Select Time'));
      await tester.pumpAndSettle();

      // Select OK on TimePicker
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Tap Confirm with all fields filled
      await tester.tap(find.text('Confirm Appointment'));
      await tester.pumpAndSettle();

      // Should have successfully created appointment
      final appointments = await DatabaseHelper.instance.getAppointments();
      expect(appointments.length, 1);
      expect(appointments.first.customerName, 'John Doe');
      expect(appointments.first.status, 'scheduled');
    });

    testWidgets('AppointmentsScreen displays and cancels appointment', (
      WidgetTester tester,
    ) async {
      // Insert a mock service so the name resolves correctly
      await DatabaseHelper.instance.database.then(
        (db) => db.insert(DatabaseHelper.tableServices, {
          'id': 1,
          'name': 'General Consultation',
          'description': 'Routine check-ups',
          'icon': 'consultation',
          'is_active': 1,
        }),
      );

      // Insert a mock appointment
      final appointment = Appointment(
        serviceId: 1,
        customerName: 'Jane Smith',
        appointmentDate: '2026-10-05',
        appointmentTime: '14:30',
        status: 'scheduled',
        createdAt: DateTime.now(),
      );
      await DatabaseHelper.instance.insertAppointment(appointment);

      await tester.pumpWidget(
        const MaterialApp(home: AppointmentsScreen(isActive: true)),
      );
      await tester.pumpAndSettle();

      // Verify the appointment card shows up
      expect(find.text('Jane Smith'), findsOneWidget);
      expect(find.text('General Consultation'), findsOneWidget);
      expect(find.text('2026-10-05'), findsOneWidget);
      expect(find.text('14:30'), findsOneWidget);
      expect(find.text('SCHEDULED'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Confirm in the dialog (use .last because there are two 'Cancel Appointment' TextButtons on screen)
      await tester.tap(
        find.widgetWithText(TextButton, 'Cancel Appointment').last,
      );
      await tester.pumpAndSettle();

      // Status should be changed to CANCELLED in UI
      expect(find.text('CANCELLED'), findsOneWidget);
      // Cancel button should no longer exist
      expect(find.text('Cancel'), findsNothing);

      // Check Database
      final dbAppointments = await DatabaseHelper.instance.getAppointments();
      expect(dbAppointments.length, 1);
      expect(dbAppointments.first.status, 'cancelled');
    });
  });
}
