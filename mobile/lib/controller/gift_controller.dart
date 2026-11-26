import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../models/data_models/gift_record.dart';
import '../models/ui_models/gift_status.dart';
import '../repository/gift_repository.dart';
import '../services/application/sync_service.dart';
import 'event_controller.dart';

/// Danh sách / thống kê của sự kiện đang chọn (permanent).
class GiftController extends GetxController {
  GiftController(this._repo, this._events, this._sync);

  final GiftRepository _repo;
  final EventController _events;
  final SyncService _sync;
  static const _uuid = Uuid();

  final RxList<GiftRecord> gifts = <GiftRecord>[].obs;
  final RxList<RelationshipStat> relCounts = <RelationshipStat>[].obs;
  final Rx<EventStats> stats = EventStats.empty().obs;
  final RxString query = ''.obs;
  final RxnString relFilter = RxnString();
  final RxnString sideFilter = RxnString();
  final RxBool groupByRel = false.obs;
  final Rxn<GiftStatus> statusFilter = Rxn<GiftStatus>();
  final RxBool loading = false.obs;

  /// Tiền đã xác nhận thêm trong hôm nay của sự kiện đang chọn (thẻ tăng trưởng ở Trang chủ).
  final RxInt todayVnd = 0.obs;

  String? get eventId => _events.active.value?.id;

  @override
  void onInit() {
    super.onInit();
    ever(_events.active, (_) {
      relFilter.value = null;
      query.value = '';
      reload();
    });
    ever(_sync.dataVersion, (_) => reload());
    debounce(query, (_) => reload(), time: const Duration(milliseconds: 250));
    ever(relFilter, (_) => reload());
    ever(sideFilter, (_) {
      relFilter.value = null;
      reload();
    });
    ever(statusFilter, (_) => reload());
  }

  Future<void> reload() async {
    final id = eventId;
    if (id == null) {
      gifts.clear();
      relCounts.clear();
      todayVnd.value = 0;
      stats.value = EventStats.empty();
      return;
    }
    loading.value = true;
    try {
      gifts.assignAll(
        await _repo.list(
          id,
          query: query.value,
          relationship: relFilter.value,
          side: sideFilter.value,
          statuses: statusFilter.value != null
              ? [statusFilter.value!]
              : [
                  GiftStatus.confirmed,
                  GiftStatus.pendingReview,
                  GiftStatus.failed,
                ],
        ),
      );
      relCounts.assignAll(
          await _repo.relationshipCounts(id, side: sideFilter.value));
      stats.value = await _repo.stats(id);
      final now = DateTime.now();
      todayVnd.value = await _repo.confirmedSince(
        id,
        DateTime(now.year, now.month, now.day),
      );
      _events.refreshTotals();
    } finally {
      loading.value = false;
    }
  }

  /// Tổng số phong bì (confirmed + pending) hiện có trong event, cho chip "Tất cả".
  int get allCount => relCounts.fold(0, (a, b) => a + b.count);

  Future<List<GiftRecord>> duplicatesOf(
    String name,
    int amount, {
    String? excludeId,
  }) =>
      eventId == null
          ? Future.value(const [])
          : _repo.findDuplicates(eventId!, name, amount, excludeId: excludeId);

  /// Nhập tay (X02): lưu local + enqueue sync. Đã xác nhận ngay (người nhập
  /// tự điền nên không mơ hồ).
  Future<GiftRecord> addManual({
    required String name,
    required int amount,
    String? relationship,
    String? note,
    String side = GiftSide.mine,
    List<String> warnings = const [],
  }) async {
    final g = GiftRecord(
      id: _uuid.v4(),
      eventId: eventId!,
      guestName: name.trim(),
      relationship: _clean(relationship),
      amountVnd: amount,
      note: _clean(note),
      side: side,
      status: GiftStatus.confirmed,
      source: GiftSource.manual,
      warnings: warnings,
    );
    await _repo.save(g);
    _sync.schedule();
    await reload();
    return g;
  }

  Future<void> updateGift(
    GiftRecord g, {
    required String name,
    required int amount,
    String? relationship,
    String? note,
    String? side,
    GiftStatus? status,
  }) async {
    await _repo.save(
      g.copyWith(
        guestName: name.trim(),
        amountVnd: amount,
        relationship: _clean(relationship),
        note: _clean(note),
        side: side,
        status: status ?? g.status,
        warnings: const [],
        errorMessage: null,
      ),
    );
    _sync.schedule();
    await reload();
  }

  /// Xác nhận bản ghi AI đang chờ (có thể đã sửa).
  Future<void> confirm(
    GiftRecord g, {
    String? name,
    int? amount,
    String? relationship,
  }) =>
      updateGift(
        g,
        name: name ?? g.guestName,
        amount: amount ?? g.amountVnd,
        relationship: relationship ?? g.relationship,
        note: g.note,
        status: GiftStatus.confirmed,
      );

  Future<void> delete(String id) async {
    await _repo.softDelete(id);
    _sync.schedule();
    await reload();
  }

  Future<void> undoDelete(String id) async {
    await _repo.restore(id);
    _sync.schedule();
    await reload();
  }

  String? _clean(String? s) {
    final t = (s ?? '').trim();
    return t.isEmpty ? null : t;
  }
}
