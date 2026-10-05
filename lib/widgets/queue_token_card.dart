import 'package:flutter/material.dart';

import '../models/queue_token.dart';
import '../models/service.dart';
import '../utils/app_colors.dart';
import '../utils/icon_helper.dart';
import '../utils/qr_payload.dart';
import '../screens/qr_display_screen.dart';

class QueueTokenCard extends StatelessWidget {
  final QueueToken token;
  final Service service;
  final VoidCallback onLeave;

  const QueueTokenCard({
    super.key,
    required this.token,
    required this.service,
    required this.onLeave,
  });

  Color _getStatusColor() {
    switch (token.status.toLowerCase()) {
      case 'waiting':
        return AppColors.statusWaiting;
      case 'serving':
        return AppColors.statusActive;
      case 'completed':
        return AppColors.statusDone;
      case 'cancelled':
        return AppColors.statusCancelled;
      default:
        return AppColors.textSecondary;
    }
  }

  String _formatTime(DateTime time) {
    final localTime = time.toLocal();
    final hour = localTime.hour;
    final minute = localTime.minute.toString().padLeft(2, '0');
    final amPm = hour >= 12 ? 'PM' : 'AM';
    final formattedHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$formattedHour:$minute $amPm';
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    final takenTime = _formatTime(token.createdAt);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Token # and Service
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  serviceIconFromString(service.icon),
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOKEN #${token.tokenNumber}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      service.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: AppColors.divider, height: 1),
          ),
          
          // Status Info Grid
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Status',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withAlpha(20),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        token.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Estimated Wait',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '~${token.estimatedWaitTime} min',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Taken At',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      takenTime,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          if (token.isActive && token.peopleAhead != null && token.currentTokenNumber != null) ...[
            const SizedBox(height: 16),
            if (token.status == 'serving')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.statusActive.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.statusActive.withAlpha(50)),
                ),
                child: const Center(
                  child: Text(
                    '🎉 Your Turn! Now Serving You',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.statusActive,
                    ),
                  ),
                ),
              )
            else if (token.status == 'waiting' && token.peopleAhead == 1)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withAlpha(50)),
                ),
                child: const Center(
                  child: Text(
                    '🔔 You\'re Next! 1 person ahead of you',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.orange,
                    ),
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.people_outline, size: 14, color: AppColors.textSecondary),
                            SizedBox(width: 4),
                            Text(
                              'People Ahead',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${token.peopleAhead}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.tag, size: 14, color: AppColors.textSecondary),
                            SizedBox(width: 4),
                            Text(
                              'Current Token',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '#${token.currentTokenNumber}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
          
          const SizedBox(height: 24),
          
          // Action Buttons
          if (token.isActive) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => QrDisplayScreen(
                            qrData: QrPayloadService.encodeQueueToken(token.id!),
                            title: 'Token #${token.tokenNumber}',
                            subtitle: service.name,
                            status: token.status,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.qr_code),
                    label: const Text('Show QR'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onLeave,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.statusCancelled,
                      side: const BorderSide(color: AppColors.statusCancelled),
                    ),
                    child: const Text('Leave Queue'),
                  ),
                ),
              ],
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.divider),
                ),
                child: Text(token.status.toUpperCase()),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
