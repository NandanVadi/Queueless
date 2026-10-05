import 'package:flutter/material.dart';

/// Central color palette for QueueLess.
///
/// All screens and widgets should reference these constants instead of
/// hard-coding hex values. This makes future re-theming trivial.
class AppColors {
  AppColors._(); // prevent instantiation

  // ---------- Brand ----------
  /// Primary brand colour — a professional deep indigo-blue.
  static const Color primary = Color(0xFF3B5BDB);

  /// A slightly lighter tint used for hover / focus states.
  static const Color primaryLight = Color(0xFF6384F5);

  /// A deep, accessible shade for pressed states.
  static const Color primaryDark = Color(0xFF2340B0);

  // ---------- Accent ----------
  /// Accent used for secondary actions (e.g. "Book Appointment" chip).
  static const Color accent = Color(0xFF0D9488); // Teal-600

  // ---------- Semantic ----------
  /// Green — active / serving status.
  static const Color statusActive = Color(0xFF16A34A);

  /// Amber — waiting status.
  static const Color statusWaiting = Color(0xFFD97706);

  /// Red — cancelled / error status.
  static const Color statusCancelled = Color(0xFFDC2626);

  /// Grey — completed / inactive status.
  static const Color statusDone = Color(0xFF6B7280);

  // ---------- Neutrals ----------
  static const Color surface = Color(0xFFF4F6FB);
  static const Color cardSurface = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFE5E7EB);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);
}
