import 'package:flutter/material.dart';

abstract final class AppSpacing {
  // Padding scale
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const xl = 28.0;

  /// Outer screen padding, matching the mockup's `28px 20px 24px`.
  static const screenPadding = EdgeInsets.fromLTRB(20, 28, 20, 24);

  /// Corner radius — buttons only. The approved design has no rounded
  /// cards; dividers replace them entirely.
  static const buttonRadius = BorderRadius.all(Radius.circular(10));

  static const progressBarRadius = BorderRadius.all(Radius.circular(2));

  /// Hairline dividers between sections and list rows — the design's
  /// substitute for card borders.
  static const dividerWidth = 0.5;

  static const progressBarHeight = 3.0;
  static const progressBarWidth = 56.0;

  // Gaps between elements
  static const gapTiny = 3.0;
  static const gapSmall = 6.0;
  static const gapMedium = 14.0;
  static const gapLarge = 24.0;
  static const gapSection = 32.0;
}
