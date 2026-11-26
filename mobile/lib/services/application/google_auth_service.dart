import 'package:asc_common/asc_common.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../configs/pref_const.dart';
import '../../controller/settings_controller.dart';
import 'api_client.dart';
import 'sync_service.dart';

class GoogleAuthException implements Exception {
  GoogleAuthException(this.code);

  /// not_configured | cancelled | failed
  final String code;
  @override
  String toString() => 'GoogleAuthException($code)';
}

/// Đăng nhập Google (tuỳ chọn). Guest vẫn dùng được đầy đủ; đăng nhập để dữ liệu
/// theo tài khoản và dùng được trên nhiều thiết bị. Backend gộp dữ liệu guest vào tài khoản.
class GoogleAuthService extends GetxService {
  GoogleAuthService(this._api, this._settings, this._sync);

  final ApiClient _api;
  final SettingsController _settings;
  final SyncService _sync;
  static final AscLogger _log = AscLogger();

  /// Web client ID của OAuth (không phải Android client ID):
  /// `--dart-define=GOOGLE_SERVER_CLIENT_ID=xxxx.apps.googleusercontent.com`
  static const String serverClientId =
      String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

  static bool get isConfigured => serverClientId.isNotEmpty;

  bool _inited = false;

  Future<void> _init() async {
    if (_inited) return;
    await GoogleSignIn.instance.initialize(serverClientId: serverClientId);
    _inited = true;
  }

  Future<void> signIn() async {
    if (!isConfigured) throw GoogleAuthException('not_configured');
    try {
      await _init();
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) throw GoogleAuthException('failed');
      final name = await _api.loginGoogle(idToken);
      await _settings.setAccount(
        email: account.email,
        name: account.displayName ?? name,
      );
      // Thiết bị mới/đăng nhập lại: kéo dữ liệu tài khoản về (upsert, không nhân đôi) rồi đẩy phần còn chờ.
      try {
        await _sync.restoreFromServer();
        await _sync.sync(force: true);
      } catch (e) {
        _log.warning('post-login sync failed: $e');
      }
    } on GoogleSignInException catch (e) {
      _log.warning('google sign-in: ${e.code}');
      throw GoogleAuthException(
        e.code == GoogleSignInExceptionCode.canceled ? 'cancelled' : 'failed',
      );
    }
  }

  Future<void> signOut() async {
    try {
      if (_inited) await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await _api.clearTokens(); // lần gọi tiếp theo tự tạo phiên guest
    await _settings.setAccount(email: null, name: null);
    final p = await SharedPreferences.getInstance();
    await p.remove(PrefConst.lastSyncAt);
  }
}
