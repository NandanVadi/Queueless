import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

/// A reusable empty-state widget used by [MyQueueScreen], [AppointmentsScreen],
/// and any future screen that needs to communicate "nothing here yet."
///
/// Shows an icon, a bold title, and a supporting body message.
///
/// Example usage:
/// ```dart
/// EmptyState(
///   icon: Icons.confirmation_number_outlined,
///   title: 'No Active Queue',
///   message: 'Take a token from a service to see your queue here.',
/// )
/// ```
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(18),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 44,
                color: AppColors.primary.withAlpha(160),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
