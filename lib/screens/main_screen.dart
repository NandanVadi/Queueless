import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'my_queue_screen.dart';
import 'appointments_screen.dart';
import 'operator_screen.dart';
import 'admin_screen.dart';
import '../models/user.dart';

/// [MainScreen] is the root shell of QueueLess.
///
/// It owns the [NavigationBar] and uses [IndexedStack] to preserve the scroll
/// position and state of each tab when the user switches between them.
///
/// Tab order:
///   0 → Home
///   1 → My Queue
///   2 → Appointments
///
/// Navigation logic lives exclusively in this widget.  Child screens receive
/// an [onNavigate] callback if they need to switch tabs (e.g. the Home screen
/// CTAs), keeping coupling minimal.
class MainScreen extends StatefulWidget {
  final User? currentUser;

  const MainScreen({super.key, this.currentUser});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  /// Switches the visible tab. Called directly and also passed as a callback
  /// to [HomeScreen] so its CTA buttons can navigate to other tabs.
  void _navigateTo(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final isOperator = widget.currentUser?.role == 'operator';
    final isAdmin = widget.currentUser?.role == 'admin';

    // The order of screens must match the destinations list below.
    // However, since operator and admin are mutually exclusive in UI tabs (or added conditionally),
    // we need to be careful with indexing.
    // Let's dynamically build the screens and destinations based on roles.
    final screens = <Widget>[
      HomeScreen(onNavigate: _navigateTo),
      MyQueueScreen(isActive: _currentIndex == 1),
      AppointmentsScreen(isActive: _currentIndex == 2),
    ];
    
    final destinations = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home_rounded),
        label: 'Home',
      ),
      const NavigationDestination(
        icon: Icon(Icons.confirmation_number_outlined),
        selectedIcon: Icon(Icons.confirmation_number_rounded),
        label: 'My Queue',
      ),
      const NavigationDestination(
        icon: Icon(Icons.calendar_today_outlined),
        selectedIcon: Icon(Icons.calendar_month_rounded),
        label: 'Appointments',
      ),
    ];

    if (isOperator) {
      screens.add(const OperatorScreen());
      destinations.add(
        const NavigationDestination(
          icon: Icon(Icons.admin_panel_settings_outlined),
          selectedIcon: Icon(Icons.admin_panel_settings_rounded),
          label: 'Operator',
        ),
      );
    }

    if (isAdmin) {
      screens.add(const AdminScreen());
      destinations.add(
        const NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings_rounded),
          label: 'Admin',
        ),
      );
    }

    // Ensure _currentIndex is within bounds if role changes
    final safeIndex = _currentIndex < screens.length ? _currentIndex : 0;

    return Scaffold(
      body: IndexedStack(
        index: safeIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: _navigateTo,
        destinations: destinations,
      ),
    );
  }
}
