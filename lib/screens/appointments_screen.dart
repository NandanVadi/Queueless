import 'package:flutter/material.dart';
import '../models/appointment.dart';
import '../database/database_helper.dart';
import '../repositories/appointment_repository.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../widgets/empty_state.dart';
import '../widgets/appointment_card.dart';

class AppointmentsScreen extends StatefulWidget {
  final bool isActive;
  
  const AppointmentsScreen({
    super.key,
    this.isActive = false,
  });

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Appointment> _appointments = [];
  Map<int, String> _serviceNames = {};
  late final AppointmentRepository _appointmentRepository;

  @override
  void initState() {
    super.initState();
    _appointmentRepository = AppointmentRepository();
    _loadAppointments();
  }
  
  @override
  void didUpdateWidget(AppointmentsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload when the tab becomes active
    if (widget.isActive && !oldWidget.isActive) {
      _loadAppointments();
    }
  }

  Future<void> _loadAppointments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final db = DatabaseHelper.instance;
      
      // Load both appointments and services
      final appointments = await _appointmentRepository.getAppointments();
      final services = await db.getServices();
      
      if (!mounted) return;

      // Build a map of serviceId -> serviceName for quick lookup
      final Map<int, String> serviceNames = {};
      for (final service in services) {
        if (service.id != null) {
          serviceNames[service.id!] = service.name;
        }
      }

      setState(() {
        _appointments = appointments;
        _serviceNames = serviceNames;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load appointments. Please try again.';
      });
    }
  }

  Future<void> _cancelAppointment(Appointment appointment) async {
    if (appointment.id == null) return;
    try {
      await _appointmentRepository.cancelAppointment(appointment.id!);
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Appointment cancelled successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      
      _loadAppointments();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to cancel appointment. Please try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Appointments'),
      ),
      body: _buildBody(),
    );
  }
  
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.statusCancelled,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _loadAppointments,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_appointments.isEmpty) {
      return const EmptyState(
        icon: Icons.calendar_today_outlined,
        title: 'No Appointments Yet',
        message: 'Your booked appointments will appear here. Book one from the Home screen.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAppointments,
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _appointments.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final appointment = _appointments[index];
          final serviceName = _serviceNames[appointment.serviceId] ?? 'Unknown Service';
          
          return AppointmentCard(
            appointment: appointment,
            serviceName: serviceName,
            onCancel: () => _cancelAppointment(appointment),
          );
        },
      ),
    );
  }
}
