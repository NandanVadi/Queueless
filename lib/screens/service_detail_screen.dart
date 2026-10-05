import 'package:flutter/material.dart';
import '../models/service.dart';
import '../repositories/queue_repository.dart';
import '../database/database_helper.dart';
import '../utils/app_colors.dart';
import '../utils/icon_helper.dart';
import 'appointment_form_screen.dart';

/// Displays the full details of a selected [Service].
///
/// Reached by tapping a [ServiceCard] on the Home screen.
/// Receives a [Service] object via the constructor — no additional
/// database call is needed since the object was already loaded on
/// the Home screen.
///
/// Milestone 4 scope:
///   - Display: name, description, icon, active/inactive status.
///   - "Take a Token" and "Book Appointment" buttons are present but
///     not yet connected to database operations (Milestone 5+).
class ServiceDetailScreen extends StatefulWidget {
  const ServiceDetailScreen({super.key, required this.service});

  /// The service record selected by the user on the Home screen.
  final Service service;

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  bool _isCreatingToken = false;
  final QueueRepository _queueRepository = QueueRepository();

  Future<void> _takeToken() async {
    if (_isCreatingToken) return;
    
    setState(() => _isCreatingToken = true);
    
    try {
      // 1. Check for duplicate active tokens locally first to save a network request
      final activeToken = await DatabaseHelper.instance.getActiveQueueTokenForService(widget.service.id!);
      if (!mounted) return;
      
      if (activeToken != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You already have an active token for this service.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop(true); // Return true to trigger navigation to My Queue
        return;
      }

      // Create and insert token using QueueRepository which coordinates Backend + SQLite
      final newToken = await _queueRepository.createQueueToken(widget.service.id!);
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Token #${newToken.tokenNumber} generated successfully!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to join queue. Please check your connection and try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCreatingToken = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(service.name),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Icon hero banner ─────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, Color(0xFF6384F5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(30),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      serviceIconFromString(service.icon),
                      size: 44,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    service.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Active / inactive status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: service.isActive
                          ? Colors.white.withAlpha(30)
                          : Colors.black.withAlpha(30),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: service.isActive
                            ? Colors.white60
                            : Colors.white30,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          service.isActive
                              ? Icons.check_circle_outline
                              : Icons.pause_circle_outline,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          service.isActive ? 'Currently Active' : 'Inactive',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Description card ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'About this service',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
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
                    child: Text(
                      service.description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.55,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Action buttons ───────────────────────────────────────
                  const Text(
                    'What would you like to do?',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Primary CTA: Take a Token
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: service.isActive
                          ? (_isCreatingToken ? null : _takeToken)
                          : null,
                      icon: _isCreatingToken 
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.confirmation_number_outlined),
                      label: Text(_isCreatingToken ? 'Generating...' : 'Take a Token'),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Secondary CTA: Book Appointment
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: service.isActive
                          ? () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AppointmentFormScreen(service: service),
                                ),
                              );
                              if (result == true && context.mounted) {
                                // Appointment created successfully!
                                // Pop back to HomeScreen with 2 (Appointments tab)
                                Navigator.of(context).pop(2);
                              }
                            }
                          : null,
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: const Text('Book Appointment'),
                    ),
                  ),

                  if (!service.isActive) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.statusWaiting.withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.statusWaiting.withAlpha(80),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 18,
                            color: AppColors.statusWaiting,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'This service is currently inactive and not accepting new tokens or appointments.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.statusWaiting,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

}
