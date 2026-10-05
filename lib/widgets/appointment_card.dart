import 'package:flutter/material.dart';
import '../models/appointment.dart';
import '../utils/app_colors.dart';
import '../utils/qr_payload.dart';
import '../screens/qr_display_screen.dart';

class AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final String serviceName;
  final VoidCallback onCancel;

  const AppointmentCard({
    super.key,
    required this.appointment,
    required this.serviceName,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final bool isCancelled = appointment.status == 'cancelled';
    final bool isCompleted = appointment.status == 'completed';
    final bool isActive = !isCancelled && !isCompleted;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? AppColors.primary.withAlpha(40) : AppColors.divider,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.primary.withAlpha(15)
                  : Colors.grey.withAlpha(20),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    serviceName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(appointment.status).withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getStatusColor(appointment.status).withAlpha(60),
                    ),
                  ),
                  child: Text(
                    appointment.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _getStatusColor(appointment.status),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Body section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 20, color: AppColors.textSecondary),
                    const SizedBox(width: 12),
                    Text(
                      appointment.customerName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 20, color: AppColors.textSecondary),
                    const SizedBox(width: 12),
                    Text(
                      appointment.appointmentDate,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 20, color: AppColors.textSecondary),
                    const SizedBox(width: 12),
                    Text(
                      appointment.appointmentTime,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Action section
          if (isActive) ...[
            const Divider(height: 1, color: AppColors.divider),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => QrDisplayScreen(
                              qrData: QrPayloadService.encodeAppointment(appointment.id!),
                              title: appointment.appointmentDate,
                              subtitle: serviceName,
                              status: appointment.status,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.qr_code, size: 18),
                      label: const Text('Show QR'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () {
                        _showCancelDialog(context);
                      },
                      icon: const Icon(Icons.cancel_outlined, size: 18),
                      label: const Text('Cancel'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.statusCancelled,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'scheduled':
      case 'pending':
        return AppColors.primary;
      case 'confirmed':
      case 'completed':
        return AppColors.statusActive;
      case 'cancelled':
        return AppColors.statusCancelled;
      default:
        return AppColors.textSecondary;
    }
  }

  void _showCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Appointment'),
        content: const Text(
          'Are you sure you want to cancel this appointment?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onCancel();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.statusCancelled,
            ),
            child: const Text('Cancel Appointment'),
          ),
        ],
      ),
    );
  }
}
