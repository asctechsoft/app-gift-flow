import 'dart:async';
import 'dart:io';

import 'package:asc_common/asc_common.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../configs/app_config.dart';
import '../../configs/app_figs.dart';

/// Firebase App Check: chứng minh với backend rằng request đến từ bản app thật
/// (Play Integrity), không phải script/bản clone - để lộ địa chỉ API cũng không
/// thể dùng đi gọi AI. Token gắn vào header `X-Firebase-AppCheck`.
///
/// - Bản product: Play Integrity.
/// - Bản dev/alpha/claude (phát hành nội bộ ngoài Google Play): provider debug; đặt
///   `--dart-define=APPCHECK_DEBUG_TOKEN=<uuid đã đăng ký trong Firebase Console>`
///   (build.py nhận từ biến môi trường APPCHECK_DEBUG_TOKEN).
/// Không có token (chưa cấu hình/offline) thì app vẫn chạy; backend quyết định
/// có chặn hay không theo APP_CHECK_MODE.
class AppCheckService {
  AppCheckService._();

  static final AscLogger _log = AscLogger();
  static bool _ready = false;

  /// Sau một lần lấy token thất bại (chưa đăng ký debug token, máy không có Play Services...)
  /// tạm ngừng thử để KHÔNG làm chậm mọi request API.
  static DateTime _retryAfter = DateTime.fromMillisecondsSinceEpoch(0);
  static bool get ready => _ready;

  static Future<void> init() async {
    if (!Platform.isAndroid) return; // iOS chưa cấu hình Firebase
    try {
      await Firebase.initializeApp();
      final debug = AppFigs.isShowTestOption;
      await FirebaseAppCheck.instance.activate(
        providerAndroid: debug
            ? AndroidDebugProvider(
                debugToken: AppConfig.appCheckDebugToken.isEmpty
                    ? null
                    : AppConfig.appCheckDebugToken,
              )
            : const AndroidPlayIntegrityProvider(),
      );
      _ready = true;
    } catch (e, st) {
      _log.error('app check init failed', e, st);
    }
  }

  /// Token hiện tại (SDK tự cache + làm mới). null nếu chưa sẵn sàng / lỗi.
  static Future<String?> token() async {
    if (!_ready || DateTime.now().isBefore(_retryAfter)) return null;
    try {
      final t = await FirebaseAppCheck.instance.getToken().timeout(
        const Duration(seconds: 4),
      );
      if (t == null || t.isEmpty) {
        _retryAfter = DateTime.now().add(const Duration(minutes: 5));
      }
      return t;
    } catch (_) {
      _retryAfter = DateTime.now().add(const Duration(minutes: 5));
      return null;
    }
  }
}
