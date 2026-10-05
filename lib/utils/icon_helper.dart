import 'package:flutter/material.dart';

/// Maps the icon identifier string stored in SQLite to a Flutter [IconData].
///
/// The [Service] model stores icons as plain strings (e.g. 'bank') because
/// [IconData] is a Flutter/UI concept that has no SQLite equivalent.
/// This function is the single place that resolves those strings back to icons.
///
/// When new service types are added to the database, add a matching case here.
IconData serviceIconFromString(String identifier) {
  switch (identifier) {
    case 'consultation':
      return Icons.chat_bubble_outline_rounded;
    case 'document':
      return Icons.description_outlined;
    case 'bank':
      return Icons.account_balance_outlined;
    case 'salon':
      return Icons.content_cut_rounded;
    case 'hospital':
      return Icons.local_hospital_outlined;
    case 'government':
      return Icons.admin_panel_settings_outlined;
    case 'retail':
      return Icons.storefront_outlined;
    default:
      // Fallback for any future icon identifier not yet listed above.
      return Icons.miscellaneous_services_outlined;
  }
}
