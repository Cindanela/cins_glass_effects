import 'package:flutter/material.dart';

/// Design tokens for the showcase chrome (not the glass itself).
abstract final class ShowcaseTheme {
  // Spacing / radius.
  static const double pad = 16;
  static const double gap = 12;
  static const double controlRadius = 14;
  static const double dotSize = 8;
  static const double dotActiveWidth = 18;
  static const double dotGap = 3;
  static const double sliderLabelWidth = 84;
  static const double sliderValueWidth = 40;

  // Specimen sizing.
  /// Specimen box side, as a fraction of the screen's shortest side.
  static const double specimenFraction = 0.72;
  static const double animGlassSide = 220;

  /// Keeps page-level controls clear of the chrome's bottom drawer.
  static const double pageBottomInset = 96;

  // Durations.
  static const Duration materialTween = Duration(milliseconds: 350);
  static const Duration driftPeriod = Duration(seconds: 3);
  static const Duration scrollPeriod = Duration(seconds: 8);

  // Chrome colors / text.
  static const Color chromeBg = Color(0x73000000);
  static const Color chromeFg = Colors.white;
  static const TextStyle headerTitle = TextStyle(
    color: Colors.white,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle controlLabel = TextStyle(
    color: Colors.white70,
    fontSize: 12,
  );
}
