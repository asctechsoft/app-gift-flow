import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:asc_common/asc_common.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../configs/app_config.dart';
import '../../configs/pref_const.dart';
import '../../models/data_models/parsed_gift.dart';
import 'app_check_service.dart';

/// Lỗi API thống nhất với backend: `{code, message, request_id, details?}`.
class ApiException implements Exception {
  ApiException(this.status, this.code, this.message, {this.requestId});
  final int status;
  final String code;
  final String message;
  final String? requestId;

  bool get isQuota => status == 429 || code == 'quota_exceeded';
  bool get isAuth => status == 401;

  @override
  String toString() => 'ApiException($status, $code, $message)';
}

/// Không có mạng / timeout (X05) - an toàn để thử lại.
class NetworkException implements Exception {
  NetworkException([this.message = 'network_error']);
  final String message;
  @override
  String toString() => 'NetworkException($message)';
}

/// HTTP client tới backend GiftFlow. Quản lý guest-auth + refresh token,
/// gắn `x-correlation-id` cho mọi request.
class ApiClient {
  ApiClient({http.Client? client, FlutterSecureStorage? storage})
    : _http = client ?? http.Client(),
      _secure = storage ?? const FlutterSecureStorage();

  final http.Client _http;
  final FlutterSecureStorage _secure;
  static const _uuid = Uuid();
  static final AscLogger _log = AscLogger();

  String? _access;
  Future<void>? _authFlight;

  /// Địa chỉ backend đang dùng: người dùng đặt được trong Cài đặt (máy thật
  /// cần IP LAN), mặc định lấy từ --dart-define=API_BASE_URL.
  static String baseUrl = AppConfig.apiBaseUrl;

  static Future<void> loadBaseUrl() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getString(PrefConst.serverUrl);
    if (v != null && v.isNotEmpty) baseUrl = v;
  }

  /// Đổi máy chủ: token cũ thuộc máy chủ khác nên bỏ đi, sẽ đăng nhập khách lại.
  Future<void> setBaseUrl(String url) async {
    var u = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (u.isNotEmpty && !u.startsWith('http')) u = 'http://$u';
    if (u.isEmpty) u = AppConfig.apiBaseUrl;
    final p = await SharedPreferences.getInstance();
    await p.setString(PrefConst.serverUrl, u);
    baseUrl = u;
    await clearTokens();
  }

  /// Kiểm tra máy chủ có trả lời không (GET /health/live).
  Future<bool> ping() async {
    try {
      final r = await _http
          .get(Uri.parse('$baseUrl/health/live'))
          .timeout(const Duration(seconds: 6));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Uri _uri(String path, [Map<String, String>? q]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: q);

  // ---------------------------------------------------------------- auth

  Future<String> _deviceId() async {
    final p = await SharedPreferences.getInstance();
    var id = p.getString(PrefConst.deviceId);
    if (id == null) {
      id = _uuid.v4();
      await p.setString(PrefConst.deviceId, id);
    }
    return id;
  }

  Future<void> _loadTokens() async {
    _access ??= await _secure.read(key: PrefConst.accessToken);
  }

  Future<void> _saveTokens(Map<String, dynamic> j) async {
    _access = j['access_token'] as String;
    await _secure.write(key: PrefConst.accessToken, value: _access);
    await _secure.write(
      key: PrefConst.refreshToken,
      value: j['refresh_token'] as String,
    );
  }

  Future<void> clearTokens() async {
    _access = null;
    await _secure.delete(key: PrefConst.accessToken);
    await _secure.delete(key: PrefConst.refreshToken);
  }

  /// Đảm bảo có token: refresh -> nếu fail thì đăng nhập guest lại.
  Future<void> _reauth() async {
    final running = _authFlight;
    if (running != null) return running;
    final f = _doReauth();
    _authFlight = f;
    try {
      await f;
    } finally {
      _authFlight = null;
    }
  }

  Future<void> _doReauth() async {
    final refresh = await _secure.read(key: PrefConst.refreshToken);
    if (refresh != null) {
      try {
        final j = await _send(
          'POST',
          '/v1/auth/refresh',
          body: {'refresh_token': refresh},
          authed: false,
        );
        await _saveTokens(j);
        return;
      } on ApiException catch (_) {
        // refresh hết hạn/bị thu hồi -> guest mới bên dưới
      }
    }
    final j = await _send(
      'POST',
      '/v1/auth/guest',
      body: {'device_id': await _deviceId()},
      authed: false,
    );
    await _saveTokens(j);
  }

  Future<void> ensureAuth() async {
    await _loadTokens();
    if (_access == null) await _reauth();
  }

  // ------------------------------------------------------------ transport

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, Object?>? body,
    Map<String, String>? query,
    bool authed = true,
    bool retried = false,
  }) async {
    if (authed) await ensureAuth();
    final appCheck = await AppCheckService.token();
    final headers = <String, String>{
      'content-type': 'application/json',
      'accept': 'application/json',
      'x-correlation-id': _uuid.v4(),
      'x-firebase-appcheck': ?appCheck,
      if (authed && _access != null) 'authorization': 'Bearer $_access',
    };
    final req = http.Request(method, _uri(path, query))
      ..headers.addAll(headers);
    if (body != null) req.body = jsonEncode(body);
    final res = await _exec(req, AppConfig.apiTimeout);
    if (res.statusCode == 401 && authed && !retried) {
      await _reauth();
      return _send(
        method,
        path,
        body: body,
        query: query,
        authed: authed,
        retried: true,
      );
    }
    return _decode(res);
  }

  Future<http.Response> _exec(http.BaseRequest req, Duration timeout) async {
    try {
      final streamed = await _http.send(req).timeout(timeout);
      return await http.Response.fromStream(streamed);
    } on SocketException catch (e) {
      throw NetworkException(e.message);
    } on TimeoutException {
      throw NetworkException('timeout');
    } on http.ClientException catch (e) {
      throw NetworkException(e.message);
    }
  }

  Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic> json = {};
    try {
      if (res.body.isNotEmpty) {
        final d = jsonDecode(utf8.decode(res.bodyBytes));
        if (d is Map<String, dynamic>) json = d;
      }
    } catch (_) {}
    if (res.statusCode >= 200 && res.statusCode < 300) return json;
    _log.warning('API ${res.statusCode}: ${json['code']} ${json['message']}');
    throw ApiException(
      res.statusCode,
      (json['code'] as String?) ?? 'http_${res.statusCode}',
      (json['message'] as String?) ?? 'Request failed',
      requestId: json['request_id'] as String?,
    );
  }

  // ------------------------------------------------------------- endpoints

  Future<Map<String, dynamic>> me() => _send('GET', '/v1/me');

  /// Đổi Google ID token lấy phiên đăng nhập. Gửi kèm token guest hiện tại để
  /// backend gộp dữ liệu guest vào tài khoản Google. Trả tên hiển thị (nếu có).
  /// [merge] false: chỉ đăng nhập, dùng dữ liệu của tài khoản (không gộp dữ liệu khách trên máy).
  Future<String?> loginGoogle(String idToken, {bool merge = true}) async {
    await ensureAuth();
    final j = await _send(
      'POST',
      '/v1/auth/google',
      body: {'id_token': idToken, 'merge': merge},
    );
    await _saveTokens(j);
    return j['display_name'] as String?;
  }

  /// Xem trước trước khi đăng nhập: tài khoản Google đã có dữ liệu chưa (không tạo/gộp gì).
  Future<Map<String, dynamic>> previewGoogle(String idToken) async {
    await ensureAuth();
    return _send('POST', '/v1/auth/google/preview', body: {'id_token': idToken});
  }

  Future<void> putEvent(String id, Map<String, Object?> body) =>
      _send('PUT', '/v1/events/$id', body: body);

  Future<void> deleteEvent(String id) => _send('DELETE', '/v1/events/$id');

  Future<void> putGift(String id, Map<String, Object?> body) =>
      _send('PUT', '/v1/gifts/$id', body: body);

  Future<void> deleteGift(String id) => _send('DELETE', '/v1/gifts/$id');

  Future<List<Map<String, dynamic>>> listEvents() async {
    final j = await _send('GET', '/v1/events');
    return ((j['items'] as List?) ?? const []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> listGifts(
    String eventId, {
    String? cursor,
    int limit = 200,
  }) => _send(
    'GET',
    '/v1/events/$eventId/gifts',
    query: {'limit': '$limit', 'include_deleted': 'true', 'cursor': ?cursor},
  );

  /// Phân tích văn bản đã nhận dạng trên máy (chỉ phân tích, chưa lưu).
  /// `requestId` = id bản ghi: gửi lại cùng id không gọi AI/không trừ quota lần 2.
  Future<ParsedGift> parseGift({
    required String eventId,
    required String requestId,
    required String text,
  }) async {
    final j = await _send(
      'POST',
      '/v1/ai/parse-gift',
      body: {'event_id': eventId, 'request_id': requestId, 'text': text},
    );
    return ParsedGift.fromJson(j);
  }

  // ------------------------------------------------------ kế hoạch sự kiện

  Future<void> putPlanItem(String id, Map<String, Object?> body) =>
      _send('PUT', '/v1/plan/items/$id', body: body);

  Future<void> deletePlanItem(String id) => _send('DELETE', '/v1/plan/items/$id');

  Future<List<Map<String, dynamic>>> listPlanItems(String eventId) async {
    final j = await _send('GET', '/v1/events/$eventId/plan/items');
    return ((j['items'] as List?) ?? const []).cast<Map<String, dynamic>>();
  }

  Future<void> putPlanGuest(String id, Map<String, Object?> body) =>
      _send('PUT', '/v1/plan/guests/$id', body: body);

  Future<void> deletePlanGuest(String id) =>
      _send('DELETE', '/v1/plan/guests/$id');

  Future<List<Map<String, dynamic>>> listPlanGuests(String eventId) async {
    final j = await _send('GET', '/v1/events/$eventId/plan/guests');
    return ((j['items'] as List?) ?? const []).cast<Map<String, dynamic>>();
  }

  // ----------------------------------------------------------- lịch đi mừng

  Future<void> putInvitation(String id, Map<String, Object?> body) =>
      _send('PUT', '/v1/invitations/$id', body: body);

  Future<void> deleteInvitation(String id) =>
      _send('DELETE', '/v1/invitations/$id');

  Future<List<Map<String, dynamic>>> listInvitations() async {
    final j = await _send('GET', '/v1/invitations');
    return ((j['items'] as List?) ?? const []).cast<Map<String, dynamic>>();
  }
}
