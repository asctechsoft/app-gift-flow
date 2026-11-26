import 'package:asc_common/asc_common.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../configs/pref_const.dart';
import '../../controller/settings_controller.dart';
import '../storage/database_helper.dart';
import 'api_client.dart';
import 'sync_service.dart';

class GoogleAuthException implements Exception {
  GoogleAuthException(this.code);

  /// not_configured | cancelled | failed
  final String code;
  @override
  String toString() => 'GoogleAuthException($code)';
}

/// Người dùng chọn gì khi tài khoản Google ĐÃ CÓ dữ liệu và máy này cũng có dữ liệu.
enum SyncChoice {
  /// Gộp: giữ cả dữ liệu của tài khoản lẫn dữ liệu trên máy.
  merge,

  /// Chỉ dùng dữ liệu của tài khoản: bỏ dữ liệu đang có trên máy, tải dữ liệu tài khoản về.
  useAccount,

  /// Không đăng nhập.
  cancel,
}

/// Số lượng dữ liệu để hiển thị trong hộp thoại hỏi đồng bộ.
class GoogleSyncPreview {
  GoogleSyncPreview({
    required this.email,
    required this.account,
    required this.local,
  });

  final String? email;

  /// events / gifts / plan_items / plan_guests / invitations
  final Map<String, int> account;
  final Map<String, int> local;

  static Map<String, int> _counts(Object? j) {
    final m = (j as Map?)?.cast<String, dynamic>() ?? const {};
    return {
      for (final k in const [
        'events',
        'gifts',
        'plan_items',
        'plan_guests',
        'invitations',
      ])
        k: (m[k] as num?)?.toInt() ?? 0,
    };
  }

  static GoogleSyncPreview fromApi(
    Map<String, dynamic> j,
    Map<String, int> local,
  ) => GoogleSyncPreview(
    email: j['email'] as String?,
    account: _counts(j['account']),
    local: local,
  );
}

/// Kết quả đăng nhập để hiển thị thông báo.
class GoogleSignInOutcome {
  GoogleSignInOutcome({required this.merged, required this.restored});

  /// Dữ liệu trên máy đã được gộp vào tài khoản.
  final bool merged;

  /// Số bản ghi đã tải từ tài khoản về máy.
  final int restored;
}

/// Đăng nhập Google (tuỳ chọn). Guest vẫn dùng được đầy đủ; đăng nhập để dữ liệu
/// theo tài khoản, dùng được trên nhiều thiết bị và khôi phục được khi cài lại app.
///
/// Luồng:
///  1. Chọn tài khoản Google -> ID token.
///  2. `preview`: tài khoản đã có dữ liệu chưa? (không tạo/gộp gì)
///  3. Tài khoản ĐÃ có dữ liệu VÀ máy cũng có dữ liệu -> hỏi: Gộp / Chỉ dùng dữ liệu tài khoản / Hủy.
///     Ngược lại (tài khoản mới, hoặc máy trống như vừa cài lại) -> tự động.
///  4. Đăng nhập (+ gộp nếu chọn), tải dữ liệu tài khoản về, đẩy phần còn chờ.
class GoogleAuthService extends GetxService {
  GoogleAuthService(this._api, this._settings, this._sync);

  final ApiClient _api;
  final SettingsController _settings;
  final SyncService _sync;
  static final AscLogger _log = AscLogger();

  /// Web client ID của OAuth (không phải Android client ID):
  /// `--dart-define=GOOGLE_SERVER_CLIENT_ID=xxxx.apps.googleusercontent.com`
  static const String serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  static bool get isConfigured => serverClientId.isNotEmpty;

  bool _inited = false;

  Future<void> _init() async {
    if (_inited) return;
    await GoogleSignIn.instance.initialize(serverClientId: serverClientId);
    _inited = true;
  }

  /// [onChoose] chỉ được gọi khi cần hỏi (tài khoản và máy đều đã có dữ liệu).
  /// [onRestoring] báo bắt đầu tải dữ liệu về (để hiện tiến trình).
  Future<GoogleSignInOutcome> signIn({
    required Future<SyncChoice> Function(GoogleSyncPreview p) onChoose,
    void Function()? onRestoring,
  }) async {
    if (!isConfigured) throw GoogleAuthException('not_configured');
    try {
      await _init();
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) throw GoogleAuthException('failed');

      final preview = await _api.previewGoogle(idToken);
      final local = await DatabaseHelper.instance.countLocal();
      final accountHasData = preview['account_has_data'] == true;
      final localHasData = local.values.any((n) => n > 0);

      var merge = true;
      if (accountHasData && localHasData) {
        final choice = await onChoose(GoogleSyncPreview.fromApi(preview, local));
        if (choice == SyncChoice.cancel) {
          try {
            await GoogleSignIn.instance.signOut();
          } catch (_) {}
          throw GoogleAuthException('cancelled');
        }
        merge = choice == SyncChoice.merge;
      }

      final name = await _api.loginGoogle(idToken, merge: merge);
      if (!merge) {
        // Chỉ dùng dữ liệu tài khoản: bỏ dữ liệu cục bộ (và hàng đợi đồng bộ) trước khi tải về.
        await DatabaseHelper.instance.clearAll();
      }
      await _settings.setAccount(
        email: account.email,
        name: account.displayName ?? name,
      );

      onRestoring?.call();
      var restored = 0;
      try {
        // Thiết bị mới/cài lại/đăng nhập lại: kéo dữ liệu tài khoản về (upsert theo id,
        // không nhân đôi) rồi đẩy phần còn chờ.
        restored = await _sync.restoreFromServer();
        await _sync.sync(force: true);
      } catch (e) {
        _log.warning('post-login sync failed: $e');
      }
      return GoogleSignInOutcome(merged: merge && localHasData, restored: restored);
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
