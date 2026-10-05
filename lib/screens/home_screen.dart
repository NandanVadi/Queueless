import 'package:flutter/material.dart';
import '../repositories/service_repository.dart';
import '../models/service.dart';
import '../utils/app_colors.dart';
import '../widgets/service_card.dart';
import '../widgets/empty_state.dart';
import 'service_detail_screen.dart';
import 'qr_scanner_screen.dart';
import 'profile_screen.dart';
import '../repositories/queue_repository.dart';
import '../repositories/appointment_repository.dart';
import '../services/api_service.dart';
import '../models/queue_token.dart';
import '../models/appointment.dart';
import '../models/user.dart';

/// The Home screen — first tab visible to the user.
///
/// Milestone 4 changes:
///   - Converted from [StatelessWidget] to [StatefulWidget] to manage
///     the async database loading lifecycle.
///   - Services are loaded from SQLite via [DatabaseHelper.instance.getServices].
///   - Only [isActive] services are presented in the grid.
///   - Loading / error / empty states are handled explicitly.
///   - Tapping a [ServiceCard] navigates to [ServiceDetailScreen].
///
/// [onNavigate] is still used by the hero-section CTAs to switch tabs.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onNavigate});

  /// Provided by [MainScreen] to switch to a given bottom-nav tab index.
  final void Function(int tabIndex) onNavigate;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ServiceRepository _serviceRepository = ServiceRepository();
  final QueueRepository _queueRepository = QueueRepository();
  final AppointmentRepository _appointmentRepository = AppointmentRepository();
  final ApiService _apiService = ApiService();

  List<Service> _services = [];
  QueueToken? _activeQueueToken;
  Appointment? _upcomingAppointment;
  User? _currentUser;

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Queries SQLite for services and updates the UI.
  ///
  /// Follows the Lab 8 async pattern:
  ///   database query → `List<Service>` → setState() → UI rebuild
  ///
  /// The `if (!mounted) return` guard prevents calling setState after the
  /// widget has been disposed — important when awaiting async operations.
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _serviceRepository.getServices(),
        _queueRepository.getActiveQueueTokens(),
        _appointmentRepository.getAppointments(),
      ]);

      User? user;
      try {
        user = await _apiService.getCurrentUser();
      } catch (_) {}

      if (!mounted) return;

      final activeServices = results[0] as List<Service>;
      final queueTokens = results[1] as List<QueueToken>;
      final appointments = results[2] as List<Appointment>;

      final activeTokens = queueTokens.where((t) => t.status == 'waiting' || t.status == 'serving').toList();
      final upcomingAppts = appointments.where((a) => a.status == 'scheduled').toList();

      setState(() {
        _services = activeServices;
        _activeQueueToken = activeTokens.isNotEmpty ? activeTokens.first : null;
        _upcomingAppointment = upcomingAppts.isNotEmpty ? upcomingAppts.first : null;
        _currentUser = user;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load services. Please try again.';
      });
    }
  }

  /// Opens [ServiceDetailScreen] for the selected service using standard
  /// Flutter push navigation — no navigation package needed.
  void _navigateToDetail(Service service) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ServiceDetailScreen(service: service),
      ),
    );
    if (result is int && mounted) {
      widget.onNavigate(result);
    } else if (result == true && mounted) {
      widget.onNavigate(1); // 1 = My Queue Tab (legacy)
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Sticky App Bar ──────────────────────────────────────────────
            SliverAppBar(
              pinned: true,
              backgroundColor: AppColors.surface,
              scrolledUnderElevation: 1,
              title: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.queue,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'QueueLess',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner, color: AppColors.primary),
                  tooltip: 'Scan QR',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const QrScannerScreen(),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.person, color: AppColors.primary),
                  tooltip: 'Profile',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ProfileScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
              ],
            ),

            // ── Scrollable content ───────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── Hero section (always visible) ────────────────────────
                  if (_currentUser != null) ...[
                    Text(
                      'Welcome back, ${_currentUser!.name.split(' ')[0]} 👋',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (_activeQueueToken != null || _upcomingAppointment != null) ...[
                    const _SectionHeader(title: 'Your Activity'),
                    const SizedBox(height: 12),
                    if (_activeQueueToken != null)
                      _ActivityCard(
                        title: 'Active Queue Token',
                        subtitle: 'Token #${_activeQueueToken!.tokenNumber}',
                        status: _activeQueueToken!.status.toUpperCase(),
                        icon: Icons.confirmation_number_outlined,
                        onTap: () => widget.onNavigate(1), // My Queue tab
                      ),
                    if (_activeQueueToken != null && _upcomingAppointment != null)
                      const SizedBox(height: 8),
                    if (_upcomingAppointment != null)
                      _ActivityCard(
                        title: 'Upcoming Appointment',
                        subtitle: '${_upcomingAppointment!.appointmentDate} • ${_upcomingAppointment!.appointmentTime}',
                        status: _upcomingAppointment!.status.toUpperCase(),
                        icon: Icons.calendar_today_outlined,
                        onTap: () => widget.onNavigate(2), // Appointments tab
                      ),
                    const SizedBox(height: 32),
                  ],
                  _HeroSection(onNavigate: widget.onNavigate),
                  const SizedBox(height: 32),

                  // ── Service discovery header ─────────────────────────────
                  const _SectionHeader(title: 'Browse Services'),
                  const SizedBox(height: 4),
                  Text(
                    'Tap a service to view details and join its queue.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),

                  // ── Service grid — driven by SQLite ──────────────────────
                  _buildServiceGrid(),
                  const SizedBox(height: 32),

                  // ── How it works (always visible) ────────────────────────
                  const _SectionHeader(title: 'How QueueLess Works'),
                  const SizedBox(height: 16),
                  const _HowItWorksSection(),
                  const SizedBox(height: 16),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the appropriate widget for the service grid area based on state.
  ///
  /// Three possible states:
  ///   1. Loading — show a centered progress indicator.
  ///   2. Error   — show an error card with a Retry button.
  ///   3. Empty   — show an [EmptyState] explaining there are no services.
  ///   4. Data    — show the [ServiceCard] grid.
  Widget _buildServiceGrid() {
    if (_isLoading) {
      return const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return _ServiceErrorState(
        message: _errorMessage!,
        onRetry: _loadData,
      );
    }

    if (_services.isEmpty) {
      return const EmptyState(
        icon: Icons.miscellaneous_services_outlined,
        title: 'No Services Available',
        message: 'There are no active services at the moment. Check back later.',
      );
    }

    // Build a 2-column grid from the live SQLite data.
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.0,
      children: _services
          .map(
            (service) => ServiceCard(
              service: service,
              onTap: () => _navigateToDetail(service),
            ),
          )
          .toList(),
    );
  }
}

// ── Private sub-widgets ──────────────────────────────────────────────────────

/// Error state displayed inside the service grid area when the DB query fails.
class _ServiceErrorState extends StatelessWidget {
  const _ServiceErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.wifi_off_rounded,
            size: 40,
            color: AppColors.statusCancelled.withAlpha(180),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.onNavigate});
  final void Function(int) onNavigate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF6384F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Skip the\nphysical wait.',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.2,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Join queues digitally, track your position in real-time, and arrive just in time.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          // Primary CTA → My Queue tab
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              onPressed: () => onNavigate(1),
              icon: const Icon(Icons.confirmation_number_outlined),
              label: const Text('Take a Token'),
            ),
          ),
          const SizedBox(height: 12),

          // Secondary CTA → Appointments tab
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white60, width: 1.5),
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              onPressed: () => onNavigate(2),
              icon: const Icon(Icons.calendar_today_outlined),
              label: const Text('Book Appointment'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.2,
      ),
    );
  }
}

class _HowItWorksSection extends StatelessWidget {
  const _HowItWorksSection();

  @override
  Widget build(BuildContext context) {
    const steps = [
      _Step(
        number: '1',
        icon: Icons.search_outlined,
        title: 'Find a Service',
        body: 'Browse available service categories and select the one you need.',
      ),
      _Step(
        number: '2',
        icon: Icons.confirmation_number_outlined,
        title: 'Take a Digital Token',
        body: 'Get a virtual queue number instantly — no physical queuing required.',
      ),
      _Step(
        number: '3',
        icon: Icons.notifications_outlined,
        title: 'Arrive Just in Time',
        body: "Monitor your position and estimated wait. Show up when it's your turn.",
      ),
    ];

    return Column(
      children: steps
          .map(
            (step) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _StepTile(step: step),
            ),
          )
          .toList(),
    );
  }
}

class _Step {
  const _Step({
    required this.number,
    required this.icon,
    required this.title,
    required this.body,
  });
  final String number;
  final IconData icon;
  final String title;
  final String body;
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.step});
  final _Step step;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              step.number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  step.body,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String status;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: status == 'SERVING' || status == 'WAITING' 
                    ? AppColors.primary.withAlpha(20)
                    : Colors.green.withAlpha(20),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: status == 'SERVING' || status == 'WAITING'
                      ? AppColors.primary
                      : Colors.green,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
