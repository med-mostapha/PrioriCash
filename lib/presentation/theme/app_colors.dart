import 'package:flutter/material.dart';

@immutable
class AppColors {
  const AppColors._({
    required this.background,
    required this.textPrimary,
    required this.textSecondary,
    required this.primary,
    required this.accent,
    required this.danger,
    required this.divider,
    required this.progressTrack,
  });

  factory AppColors.of(BuildContext context) => dark;

  final Color background;

  final Color textPrimary;

  final Color textSecondary;

  final Color primary;

  final Color accent;

  final Color danger;

  final Color divider;

  final Color progressTrack;

  static const dark = AppColors._(
    background: Color(0xFF0A0A0A),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF6E6E73),
    primary: Color(0xFF5B5FEF),
    accent: Color(0xFFA8E6A3),
    danger: Color(0xFFE24B4A),
    divider: Color(0xFF1E1E1E),
    progressTrack: Color(0xFF1E1E1E),
  );
}
