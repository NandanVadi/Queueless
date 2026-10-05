import 'package:flutter/material.dart';
import 'screens/main_screen.dart';
import 'screens/splash_screen.dart';
import 'utils/app_theme.dart';

void main() {
  runApp(const QueueLessApp());
}

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Root widget for the QueueLess application.
///
/// Responsibilities:
///   - Set the application title seen by the OS task-switcher.
///   - Apply the global [AppTheme.lightTheme].
///   - Delegate navigation structure to [MainScreen].
///
/// Keep this widget small — business logic belongs in screens, not here.
class QueueLessApp extends StatelessWidget {
  final Widget? initialScreen;

  const QueueLessApp({super.key, this.initialScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: scaffoldMessengerKey,
      title: 'QueueLess',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: initialScreen ?? const SplashScreen(),
    );
  }
}
