import 'package:flutter/material.dart';
import '../models/service.dart';
import '../utils/app_colors.dart';
import '../utils/icon_helper.dart';

/// A reusable card that represents a single [Service] on the Home screen.
///
/// Accepts a real [Service] object from SQLite. The icon string stored in the
/// database is resolved to a Flutter [IconData] via [serviceIconFromString].
///
/// [onTap] is required — pass a callback that navigates to [ServiceDetailScreen].
class ServiceCard extends StatelessWidget {
  const ServiceCard({
    super.key,
    required this.service,
    required this.onTap,
  });

  /// The Service record loaded from SQLite.
  final Service service;

  /// Called when the user taps the card.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon badge — icon string from DB → IconData via helper
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  serviceIconFromString(service.icon),
                  size: 26,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 14),
              // Service name from SQLite
              Text(
                service.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              // Service description from SQLite
              Text(
                service.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
