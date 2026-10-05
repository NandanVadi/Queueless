import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:queueless/database/database_helper.dart';
import 'package:queueless/main.dart';
import 'package:queueless/screens/main_screen.dart';

/// Widget smoke tests for QueueLess.
///
/// These tests use sqflite_common_ffi so SQLite runs on the Dart VM without
/// a real device. Each test gets a fresh in-memory database (with seed data
/// from _onCreate) via setUp/tearDown.
void main() {
  // ── One-time sqflite initialisation ────────────────────────────────────────
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
    // Restore default services because tests expect them
    await db.insert(DatabaseHelper.tableServices, {
      'id': 1,
      'name': 'General Consultation',
      'description': 'Routine check-ups',
      'icon': 'consultation',
      'is_active': 1,
    });
  });

  tearDown(() async {
    // Keep DB alive
  });

  // Helper: wait for sqflite's real async isolate to return and clear the loading state.
  Future<void> pumpUntilLoaded(WidgetTester tester) async {
    for (int i = 0; i < 50; i++) {
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 10));
      });
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
        break;
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Navigation structure tests
  // ══════════════════════════════════════════════════════════════════════════

  testWidgets('QueueLessApp renders MainScreen with NavigationBar',
      (WidgetTester tester) async {
    await tester.pumpWidget(const QueueLessApp(initialScreen: MainScreen()));
    await pumpUntilLoaded(tester);

    // Bottom navigation bar must be present with all three destinations.
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('My Queue'), findsOneWidget);
    expect(find.text('Appointments'), findsOneWidget);
  });

  testWidgets('Home tab shows branding and hero CTAs',
      (WidgetTester tester) async {
    await tester.pumpWidget(const QueueLessApp(initialScreen: MainScreen()));
    await pumpUntilLoaded(tester);

    // App title in the SliverAppBar.
    expect(find.text('QueueLess'), findsWidgets);

    // Value proposition text.
    expect(find.textContaining('Skip the'), findsOneWidget);

    // Hero action buttons.
    expect(find.text('Take a Token'), findsOneWidget);
    expect(find.text('Book Appointment'), findsOneWidget);
  });

  testWidgets('Tapping My Queue tab shows empty state',
      (WidgetTester tester) async {
    await tester.pumpWidget(const QueueLessApp(initialScreen: MainScreen()));
    await pumpUntilLoaded(tester);

    await tester.tap(find.widgetWithText(NavigationDestination, 'My Queue'));
    await pumpUntilLoaded(tester);

    expect(find.text('No Active Queue'), findsOneWidget);
  });

  testWidgets('Tapping Appointments tab shows empty state',
      (WidgetTester tester) async {
    await tester.pumpWidget(const QueueLessApp(initialScreen: MainScreen()));
    await pumpUntilLoaded(tester);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Appointments'));
    await pumpUntilLoaded(tester);

    expect(find.text('No Appointments Yet'), findsOneWidget);
  });
}
