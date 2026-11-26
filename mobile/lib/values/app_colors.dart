import 'package:flutter/material.dart';

/// Design tokens GiftFlow AI - một nguồn duy nhất cho màu (sáng + tối).
///
/// Giao diện hiện tại được chọn bằng [dark] (do ThemeService đặt khi khởi động / đổi chế độ);
/// sau đó cả cây widget được dựng lại nên các getter bên dưới trả về bảng màu mới.
class AppColors {
  AppColors._();

  /// true = bảng màu tối.
  static bool dark = false;

  static Color _p(Color light, Color night) => dark ? night : light;

  // Màu thương hiệu giữ nguyên ở cả hai chế độ (đủ tương phản trên nền tối).
  static const Color primary = Color(0xFF7837E8);
  static Color get accent => _p(const Color(0xFFB56DFA), const Color(0xFFC08BFF));

  static Color get background => _p(const Color(0xFFFAF8FF), const Color(0xFF141120));
  static Color get surface => _p(const Color(0xFFFFFFFF), const Color(0xFF1F1A30));
  static Color get text => _p(const Color(0xFF201A40), const Color(0xFFEEEAFB));
  static Color get textSecondary =>
      _p(const Color(0xFF6E6890), const Color(0xFFA9A2C9));
  static Color get border => _p(const Color(0xFFE6DFF7), const Color(0xFF332C4D));
  static Color get chip => _p(const Color(0xFFF1EAFE), const Color(0xFF2B2345));
  static Color get success => _p(const Color(0xFF188B54), const Color(0xFF4FD18E));
  static Color get successBg => _p(const Color(0xFFDDF3E8), const Color(0xFF173A2A));
  static Color get warning => _p(const Color(0xFFC98319), const Color(0xFFEBAE45));
  static Color get warningBg => _p(const Color(0xFFFBEFD7), const Color(0xFF3B2E14));
  static Color get danger => _p(const Color(0xFFD93B4B), const Color(0xFFFF7381));
  static Color get dangerBg => _p(const Color(0xFFFCE4E7), const Color(0xFF3F1F27));

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF8E4DF0), Color(0xFF6A2DDB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get screenGradient => dark
      ? const LinearGradient(
          colors: [Color(0xFF1B1530), Color(0xFF141120), Color(0xFF181328)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        )
      : const LinearGradient(
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
