import 'package:get/get.dart';

import '../models/data_models/gift_record.dart';
import '../models/ui_models/gift_status.dart';
import '../repository/gift_filter.dart';
import '../repository/gift_repository.dart';
import '../services/application/sync_service.dart';
import 'event_controller.dart';
import 'gift_controller.dart';

/// Danh sách tiền mừng + bộ lọc + chọn nhiều. Một bản "toàn bộ sự kiện" (tab Danh sách)
/// và một bản cho mỗi sự kiện (tab Phong bì trong chi tiết sự kiện, tạo bằng `tag`).
class GiftListController extends GetxController {
  GiftListController(
    this._repo,
    this._gifts,
    this._events,
    this._sync, {
    String? eventId,
  }) : filter = GiftFilter(eventId: eventId).obs;

  final GiftRepository _repo;
  final GiftController _gifts;
  final EventController _events;
  final SyncService _sync;

  final Rx<GiftFilter> filter;
  final RxList<GiftWithEvent> items = <GiftWithEvent>[].obs;
  final RxSet<String> selected = <String>{}.obs;
  final RxBool loading = false.obs;

  /// Tổng số bản ghi (mọi bộ lọc trừ ô tìm kiếm) cho chip "Tất cả (n)".
  final RxInt totalCount = 0.obs;
  final RxList<String> relationships = <String>[].obs;

  bool _disposed = false;

  @override
  void onInit() {
    super.onInit();
    ever(filter, (_) => reload());
    ever(_gifts.gifts, (_) => reload());
    ever(_sync.dataVersion, (_) => reload());
    ever(_events.events, (_) => reload());
    reload();
  }

  @override
  void onClose() {
    _disposed = true;
    super.onClose();
  }

  Future<void> reload() async {
    loading.value = true;
    try {
      final rows = await _repo.search(filter.value);
      if (_disposed) return;
      items.assignAll(rows);
      // Bỏ chọn những dòng không còn trong danh sách.
      final ids = rows.map((r) => r.gift.id).toSet();
      selected.removeWhere((id) => !ids.contains(id));
      final base = await _repo.search(
        GiftFilter(eventId: filter.value.eventId),
      );
      if (_disposed) return;
      totalCount.value = base.length;
      relationships.assignAll(
        base
            .map((r) => (r.gift.relationship ?? '').trim())
            .where((r) => r.isNotEmpty)
            .toSet()
            .toList()
          ..sort(),
      );
    } finally {
      if (!_disposed) loading.value = false;
    }
  }

  void setFilter(GiftFilter f) => filter.value = f;

  /// Số kết quả nếu áp dụng bộ lọc [f] (nút "Áp dụng (n)" trong bottom sheet).
  Future<int> countFor(GiftFilter f) async => (await _repo.search(f)).length;

  void setQuery(String q) {
    if (q == filter.value.query) return;
    filter.value = filter.value.copyWith(query: q);
  }

  // ----------------------------------------------------------- tổng hợp

  int get envelopeCount => items.length;
  int get guestCount => items
      .map((r) => r.gift.guestName.trim().toLowerCase())
      .where((n) => n.isNotEmpty)
      .toSet()
      .length;

  /// Chỉ cộng bản ghi đã xác nhận (BR10).
  int get totalVnd => items
      .where((r) => r.gift.status == GiftStatus.confirmed)
      .fold(0, (a, r) => a + r.gift.amountVnd);

  // ----------------------------------------------------------- chọn nhiều

  bool isSelected(String id) => selected.contains(id);

  void toggle(String id) {
    if (!selected.remove(id)) selected.add(id);
  }

  void clearSelection() => selected.clear();

  void selectAll() => selected.addAll(items.map((r) => r.gift.id));

  List<GiftRecord> get selectedGifts => items
      .where((r) => selected.contains(r.gift.id))
      .map((r) => r.gift)
      .toList();

  /// Xác nhận các bản ghi đang chờ trong số đã chọn (đủ tên + số tiền mới xác nhận được).
  /// Trả về (đã xác nhận, bị bỏ qua vì thiếu thông tin).
  Future<(int ok, int skipped)> confirmSelected() async {
    var ok = 0;
    var skipped = 0;
    for (final g in selectedGifts) {
      if (g.status == GiftStatus.confirmed) continue;
      if (g.guestName.trim().isEmpty || g.amountVnd <= 0) {
        skipped++;
        continue;
      }
      await _gifts.confirm(g);
      ok++;
    }
    selected.clear();
    await reload();
    return (ok, skipped);
  }

  /// Xoá mềm các bản ghi đã chọn; trả về id để hoàn tác.
  Future<List<String>> deleteSelected() async {
    final ids = selectedGifts.map((g) => g.id).toList();
    for (final id in ids) {
      await _gifts.delete(id);
    }
    selected.clear();
    await reload();
    return ids;
  }

  Future<void> undoDelete(List<String> ids) async {
    for (final id in ids) {
      await _gifts.undoDelete(id);
    }
    await reload();
  }

  Future<void> deleteOne(String id) async {
    await _gifts.delete(id);
    await reload();
  }
}
