/// Cấu hình môi trường. KHÔNG hardcode IP VPS trong bản phát hành - truyền
/// qua `--dart-define=API_BASE_URL=https://api.<domain>`.
///
/// Dev (Android emulator): backend chạy trên máy host => 10.0.2.2:3000.
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  /// Token debug App Check cho bản nội bộ (dev/alpha/claude). Không commit; truyền lúc build.
  static const String appCheckDebugToken = String.fromEnvironment(
    'APPCHECK_DEBUG_TOKEN',
  );

  static const Duration apiTimeout = Duration(seconds: 20);
  static const Duration voiceTimeout = Duration(seconds: 45);

  /// Trần số tiền một phong bì (VND) - khớp backend `MAX_AMOUNT_VND`.
  static const int maxAmountVnd = 1000000000;

  /// Ngưỡng dBFS coi là có tiếng nói khi ghi âm.
  static const double speechThresholdDb = -40;

  /// Một lượt nói ngắn hơn mức này bị bỏ (tiếng ồn).
  static const int minSegmentMs = 900;

  /// Một lượt dài hơn mức này tự cắt (giới hạn backend).
  static const int maxSegmentMs = 20000;

  /// Cảnh báo trùng nếu cùng tên + số tiền trong khoảng này (BR06).
  static const Duration duplicateWindow = Duration(minutes: 10);
}
