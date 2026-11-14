import 'package:flutter/material.dart';

/// Design tokens GiftFlow AI - một nguồn duy nhất cho màu.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF7837E8);
  static const Color accent = Color(0xFFB56DFA);
  static const Color background = Color(0xFFFAF8FF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color text = Color(0xFF201A40);
  static const Color textSecondary = Color(0xFF6E6890);
  static const Color border = Color(0xFFE6DFF7);
  static const Color chip = Color(0xFFF1EAFE);
  static const Color success = Color(0xFF188B54);
  static const Color successBg = Color(0xFFDDF3E8);
  static const Color warning = Color(0xFFC98319);
  static const Color warningBg = Color(0xFFFBEFD7);
  static const Color danger = Color(0xFFD93B4B);
  static const Color dangerBg = Color(0xFFFCE4E7);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF8E4DF0), Color(0xFF6A2DDB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient screenGradient = LinearGradient(
    colors: [Color(0xFFF2E9FF), Color(0xFFFAF8FF), Color(0xFFF6F0FF)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Màu cho từng nhóm quan hệ trong biểu đồ.
  static const List<Color> chart = [
    Color(0xFF7837E8),
    Color(0xFFB56DFA),
    Color(0xFF9D8CF2),
    Color(0xFFD6C2FA),
    Color(0xFF5B8DEF),
    Color(0xFF3FB68B),
  ];
}
