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

class VoiceSegmentResult {
  VoiceSegmentResult({
    required this.requestId,
    required this.state,
    this.transcript,
    this.guestName,
    this.relationship,
    this.amountVnd,
    this.warnings = const [],
    this.duplicateGiftIds = const [],
  });

  final String requestId;

  /// confirmed | pending_review | failed
  final String state;
  final String? transcript;
  final String? guestName;
  final String? relationship;
  final int? amountVnd;
  final List<String> warnings;
  final List<String> duplicateGiftIds;

  factory VoiceSegmentResult.fromJson(Map<String, dynamic> j) {
    final c = (j['candidate'] as Map?)?.cast<String, dynamic>() ?? {};
    return VoiceSegmentResult(
      requestId: j['request_id'] as String? ?? '',
      state: j['state'] as String? ?? 'failed',
      transcript: j['transcript'] as String?,
      guestName: c['guest_name'] as String?,
      relationship: c['relationship_label'] as String?,
      amountVnd: (c['amount_vnd'] as num?)?.toInt(),
      warnings: ((j['warnings'] as List?) ?? const []).cast<String>(),
      duplicateGiftIds: ((j['duplicate_candidates'] as List?) ?? const [])
          .map((e) => (e as Map)['gift_id'] as String)
          .toList(),
    );
  }
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

  Uri _uri(String path, [Map<String, String>? q]) =>
      Uri.parse('${AppConfig.apiBaseUrl}$path').replace(queryParameters: q);

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
    final headers = <String, String>{
      'content-type': 'application/json',
      'accept': 'application/json',
      'x-correlation-id': _uuid.v4(),
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
  Future<String?> loginGoogle(String idToken) async {
    await ensureAuth();
    final j = await _send('POST', '/v1/auth/google', body: {'id_token': idToken});
    await _saveTokens(j);
    return j['display_name'] as String?;
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

  /// Upload 1 lượt nói. `requestId` bắt buộc để backend idempotent (BR07).
  Future<VoiceSegmentResult> uploadVoiceSegment({
    required String filePath,
    required String eventId,
    required String requestId,
    required int durationMs,
    String side = 'mine',
    bool retried = false,
  }) async {
    await ensureAuth();
    final req = http.MultipartRequest('POST', _uri('/v1/voice/segments'))
      ..headers.addAll({
        'accept': 'application/json',
        'x-correlation-id': _uuid.v4(),
        if (_access != null) 'authorization': 'Bearer $_access',
      })
      ..fields['event_id'] = eventId
      ..fields['request_id'] = requestId
      ..fields['duration_ms'] = '$durationMs'
      ..fields['side'] = side
      ..files.add(await http.MultipartFile.fromPath('audio', filePath));
    final res = await _exec(req, AppConfig.voiceTimeout);
    if (res.statusCode == 401 && !retried) {
      await _reauth();
      return uploadVoiceSegment(
        filePath: filePath,
        eventId: eventId,
        requestId: requestId,
        durationMs: durationMs,
        side: side,
        retried: true,
      );
    }
    return VoiceSegmentResult.fromJson(_decode(res));
  }
}
