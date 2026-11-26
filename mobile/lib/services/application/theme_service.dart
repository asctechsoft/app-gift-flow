import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../values/app_colors.dart';

/// Chế độ giao diện: theo hệ thống / sáng / tối.
class ThemeModeKey {
  ThemeModeKey._();
  static const system = 'system';
  static const light = 'light';
  static const dark = 'dark';
  static const all = [light, dark, system];
}

/// Chọn bảng màu theo chế độ + độ sáng của hệ thống và dựng lại cây widget khi đổi.
class ThemeService {
  ThemeService._();

  /// Đặt [AppColors.dark] theo [mode]. Trả về true nếu bảng màu đổi.
  static bool apply(String mode) {
    final sys = PlatformDispatcher.instance.platformBrightness == Brightness.dark;
    final dark = mode == ThemeModeKey.dark || (mode == ThemeModeKey.system && sys);
    final changed = AppColors.dark != dark;
    AppColors.dark = dark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: const Color(0x00000000),
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      ),
    );
    return changed;
  }

  /// Đổi chế độ lúc đang chạy: áp dụng rồi dựng lại toàn bộ UI.
  static void change(String mode) {
    apply(mode);
    Get.forceAppUpdate();
  }
}
