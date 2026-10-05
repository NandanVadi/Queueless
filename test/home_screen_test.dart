import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:queueless/database/database_helper.dart';
import 'package:queueless/main.dart';
import 'package:queueless/screens/main_screen.dart';
import 'package:queueless/screens/service_detail_screen.dart';

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
    // Restore default services because HomeScreen needs them
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

  // Helper: Wait for SQLite to finish async loading and the CircularProgressIndicator to vanish.
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

  testWidgets('HomeScreen displays active services and hides inactive ones', (WidgetTester tester) async {
    // 1. Manually add specific test data.
    final db = await DatabaseHelper.instance.database;
    // Clear the auto-seeded default services to have a clean slate.
    await db.delete(DatabaseHelper.tableServices);

    // Insert an active service
    await db.insert(DatabaseHelper.tableServices, {
      'name': 'Active Test Service',
      'description': 'This should be visible',
      'icon': 'consultation',
      'is_active': 1,
    });

    // Insert an inactive service
    await db.insert(DatabaseHelper.tableServices, {
      'name': 'Inactive Test Service',
      'description': 'This should be hidden',
      'icon': 'bank',
      'is_active': 0,
    });

    // 2. Load the app
    await tester.pumpWidget(const QueueLessApp(initialScreen: MainScreen()));
    await pumpUntilLoaded(tester);

    // 3. Verify visibility
    expect(find.text('Active Test Service'), findsOneWidget);
    expect(find.text('Inactive Test Service'), findsNothing);
  });

  testWidgets('Tapping a Service navigates to ServiceDetailScreen', (WidgetTester tester) async {
    // Rely on the auto-seeded services from _onCreate
    await tester.pumpWidget(const QueueLessApp(initialScreen: MainScreen()));
    await pumpUntilLoaded(tester);

    // Find "General Consultation" which is one of the seeded defaults
    final serviceText = find.text('General Consultation');
    expect(serviceText, findsOneWidget);
    await tester.ensureVisible(serviceText);
    await tester.pumpAndSettle();
    await tester.tap(serviceText);
    await tester.pumpAndSettle(); // Settle navigation transition

    // Verify we are on the ServiceDetailScreen
    expect(find.byType(ServiceDetailScreen), findsOneWidget);
    
    // Check that the buttons exist
    expect(find.text('Take a Token'), findsOneWidget);
    expect(find.text('Book Appointment'), findsOneWidget);
  });

  testWidgets('HomeScreen displays empty state when no active services exist', (WidgetTester tester) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(DatabaseHelper.tableServices); // delete all seeded services

    await tester.pumpWidget(const QueueLessApp(initialScreen: MainScreen()));
    await pumpUntilLoaded(tester);

    // Verify empty state title
    expect(find.text('No Services Available'), findsOneWidget);
  });

  testWidgets('HomeScreen handles database errors gracefully', (WidgetTester tester) async {
    // To simulate an error, we can drop the services table entirely so the SELECT query fails.
    final db = await DatabaseHelper.instance.database;
    await db.execute('DROP TABLE ${DatabaseHelper.tableServices}');

    await tester.pumpWidget(const QueueLessApp(initialScreen: MainScreen()));
    await pumpUntilLoaded(tester);

    // The UI should catch the error and show the retry message
    expect(find.text('Could not load services. Please try again.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
