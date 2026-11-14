import 'dart:async';

import 'package:asc_common/asc_common.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../configs/pref_const.dart';
import '../../models/data_models/gift_event.dart';
import '../../models/data_models/gift_record.dart';
import '../../models/ui_models/gift_status.dart';
import '../../repository/event_repository.dart';
import '../../repository/gift_repository.dart';
import '../../repository/outbox_repository.dart';
import 'api_client.dart';

/// Đồng bộ local-first: mọi thay đổi đã ghi SQLite + outbox; service này đẩy
/// outbox lên backend khi có mạng, và kéo dữ liệu về khi khôi phục.
class SyncService extends GetxService {
  SyncService(this._api, this._outbox, this._events, this._gifts);

  final ApiClient _api;
  final OutboxRepository _outbox;
  final EventRepository _events;
  final GiftRepository _gifts;
  static final AscLogger _log = AscLogger();

  final RxInt pendingCount = 0.obs;
  final RxBool syncing = false.obs;
  final RxBool online = true.obs;
  final Rxn<DateTime> lastSyncAt = Rxn<DateTime>();
  final RxnString lastError = RxnString();

  /// Có mạng nhưng không gọi được backend (sai địa chỉ máy chủ / server tắt).
  final RxBool serverUnreachable = false.obs;

  /// Tăng mỗi khi dữ liệu local đổi do kéo từ server - UI nghe để reload.
  final RxInt dataVersion = 0.obs;

  StreamSubscription<List<dynamic>>? _connSub;
  Timer? _debounce;
  Timer? _retryTimer;

  Future<SyncService> init() async {
    final p = await SharedPreferences.getInstance();
    final ms = p.getInt(PrefConst.lastSyncAt);
    if (ms != null) lastSyncAt.value = DateTime.fromMillisecondsSinceEpoch(ms);
    online.value = await AscConnectivity.isOnline();
    _connSub = AscConnectivity.onChanged.listen((r) {
      final now = AscConnectivity.isOnlineFrom(r);
      final was = online.value;
      online.value = now;
      if (now && !was) sync();
    });
    // Server tạm không với tới (đổi URL, backend khởi động lại...): tự thử lại
    // định kỳ để không kẹt ở "ngoại tuyến" tới khi đổi mạng.
    _retryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!online.value) sync();
    });
    await refreshPending();
    return this;
  }

  @override
  void onClose() {
    _connSub?.cancel();
    _debounce?.cancel();
    _retryTimer?.cancel();
    super.onClose();
  }

  Future<void> refreshPending() async =>
      pendingCount.value = await _outbox.count();

  /// Gọi sau mỗi lần ghi local - gom lại để không bắn request liên tục.
  void schedule() {
    refreshPending();
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), sync);
  }

  Future<void> sync({bool force = false}) async {
    if (syncing.value) return;
    if (force) await _outbox.resetAttempts();
    syncing.value = true;
    lastError.value = null;
    try {
      if (!await AscConnectivity.isOnline()) {
        online.value = false;
        return;
      }
      online.value = true;
      await _api.ensureAuth();
      while (true) {
        final batch = await _outbox.pending();
        if (batch.isEmpty) break;
        var progressed = false;
        for (final item in batch) {
          try {
            await _push(item);
            await _outbox.remove(item.id);
            progressed = true;
          } on ApiException catch (e) {
            // Lỗi nghiệp vụ (4xx) của 1 bản ghi: không chặn các bản ghi khác.
            _log.warning('sync ${item.entity}/${item.entityId}: $e');
            await _outbox.markFailed(item.id, '${e.status} ${e.code}');
            lastError.value = e.message;
          }
        }
        if (!progressed) break;
      }
      final now = DateTime.now();
      lastSyncAt.value = now;
      final p = await SharedPreferences.getInstance();
      await p.setInt(PrefConst.lastSyncAt, now.millisecondsSinceEpoch);
    } on NetworkException {
      online.value = false;
    } on ApiException catch (e) {
      lastError.value = e.message;
    } catch (e, st) {
      _log.error('sync failed', e, st);
      lastError.value = '$e';
    } finally {
      syncing.value = false;
      await refreshPending();
    }
  }

  Future<void> _push(OutboxItem item) async {
    if (item.entity == 'event') {
      final e = await _events.getRaw(item.entityId);
      if (item.action == 'delete' || (e?.deletedAt != null)) {
        await _ignore404(() => _api.deleteEvent(item.entityId));
        return;
      }
      if (e == null) return;
      await _api.putEvent(e.id, e.toApi());
      await _events.markSynced(e.id, e.updatedAt);
    } else {
      final g = await _gifts.getRaw(item.entityId);
      if (item.action == 'delete' || (g?.deletedAt != null)) {
        await _ignore404(() => _api.deleteGift(item.entityId));
        return;
      }
      if (g == null) return;
      // Bản ghi đang xử lý/lỗi cục bộ không đẩy lên (chưa phải dữ liệu thật).
      if (g.status == GiftStatus.processing || g.status == GiftStatus.failed) {
        return;
      }
      await _api.putGift(g.id, g.toApi());
      await _gifts.markSynced(g.id, g.updatedAt);
    }
  }

  Future<void> _ignore404(Future<void> Function() f) async {
    try {
      await f();
    } on ApiException catch (e) {
      if (e.status != 404) rethrow;
    }
  }

  /// Khôi phục từ server (không nhân đôi: upsert theo id, mới hơn thắng).
  /// Trả số bản ghi đã nhận.
  Future<int> restoreFromServer() async {
    await _api.ensureAuth();
    var count = 0;
    final events = await _api.listEvents();
    for (final j in events) {
      await _events.upsertFromServer(_eventFromJson(j));
      count++;
      String? cursor;
      do {
        final page = await _api.listGifts(j['id'] as String, cursor: cursor);
        for (final gj in ((page['items'] as List?) ?? const [])) {
          await _gifts.upsertFromServer(
            _giftFromJson((gj as Map).cast<String, dynamic>()),
          );
          count++;
        }
        cursor = page['next_cursor'] as String?;
      } while (cursor != null);
    }
    dataVersion.value++;
    return count;
  }

  GiftEvent _eventFromJson(Map<String, dynamic> j) => GiftEvent(
    id: j['id'] as String,
    name: j['name'] as String,
    type: (j['type'] as String?) ?? 'wedding',
    eventDate: j['event_date'] as String,
    location: j['location'] as String?,
    status: (j['status'] as String?) ?? 'active',
    createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
    updatedAt: DateTime.parse(j['updated_at'] as String).toLocal(),
    deletedAt: j['deleted_at'] == null
        ? null
        : DateTime.parse(j['deleted_at'] as String).toLocal(),
    synced: true,
  );

  GiftRecord _giftFromJson(Map<String, dynamic> j) => GiftRecord(
    id: j['id'] as String,
    eventId: j['event_id'] as String,
    guestName: (j['guest_name'] as String?) ?? '',
    relationship: j['relationship_label'] as String?,
    amountVnd: (j['amount_vnd'] as num).toInt(),
    note: j['note'] as String?,
    status: GiftStatus.fromWire(j['status'] as String?),
    source: GiftSource.fromWire(j['source'] as String?),
    side: GiftSide.normalize(j['side'] as String?),
    transcript: j['transcript'] as String?,
    createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
    updatedAt: DateTime.parse(j['updated_at'] as String).toLocal(),
    deletedAt: j['deleted_at'] == null
        ? null
        : DateTime.parse(j['deleted_at'] as String).toLocal(),
    synced: true,
  );
}
