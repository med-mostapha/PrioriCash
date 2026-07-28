import 'package:flutter/material.dart';

abstract final class AppTypography {
  static const heroBalance = TextStyle(
    fontSize: 56,
    fontWeight: FontWeight.w500,
    letterSpacing: -2,
    height: 1,
  );

  static const heroBalanceFraction = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w500,
  );

  static const heroSubtitle = TextStyle(fontSize: 14);

  static const sectionLabel = TextStyle(fontSize: 11, letterSpacing: 0.5);

  static const summaryLabel = TextStyle(fontSize: 11);

  static const summaryValue = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w500,
  );

  static const screenTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
  );

  static const warning = TextStyle(fontSize: 13);

  static const buttonLabel = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  static const listItemTitle = TextStyle(fontSize: 15);

  static const listItemCaption = TextStyle(fontSize: 12);

  static const listItemAmount = TextStyle(fontSize: 15);

  static const topBarDate = TextStyle(fontSize: 13, letterSpacing: 0.3);
}
