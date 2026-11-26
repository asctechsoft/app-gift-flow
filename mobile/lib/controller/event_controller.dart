import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../models/data_models/gift_event.dart';
import '../repository/event_repository.dart';
import '../repository/gift_repository.dart';
import '../services/application/sync_service.dart';
import 'settings_controller.dart';

/// Danh sách sự kiện + sự kiện đang chọn (permanent).
class EventController extends GetxController {
  EventController(this._repo, this._giftRepo, this._settings, this._sync);

  final EventRepository _repo;
  final GiftRepository _giftRepo;
  final SettingsController _settings;
  final SyncService _sync;
  static const _uuid = Uuid();

  final RxList<GiftEvent> events = <GiftEvent>[].obs;
  final Rxn<GiftEvent> active = Rxn<GiftEvent>();
  final RxBool loaded = false.obs;

  /// Tổng tiền confirmed theo từng sự kiện (hiển thị ở danh sách sự kiện).
  final RxMap<String, int> totals = <String, int>{}.obs;

  /// Thống kê đầy đủ theo từng sự kiện (số phong bì, số khách, tổng tiền).
  final RxMap<String, EventStats> statsById = <String, EventStats>{}.obs;

  @override
  void onInit() {
    super.onInit();
    ever(_sync.dataVersion, (_) => load());
  }

  Future<void> load() async {
    events.assignAll(await _repo.list());
    final id = _settings.activeEventId;
    GiftEvent? a = events.firstWhereOrNull((e) => e.id == id);
    // Không còn sự kiện đã chọn -> lấy sự kiện đang diễn ra đầu tiên.
    a ??= events.firstWhereOrNull((e) => !e.isClosed);
    active.value = a;
    await _settings.setActiveEventId(a?.id);
    await refreshTotals();
    loaded.value = true;
  }

  Future<void> setActive(String id) async {
    await _settings.setActiveEventId(id);
    active.value = events.firstWhereOrNull((e) => e.id == id);
  }

  /// Tạo mới (id null) hoặc sửa. Trả sự kiện đã lưu.
  Future<GiftEvent> save({
    String? id,
    required String name,
    required String type,
    required String eventDate,
    String? location,
  }) async {
    final loc = (location ?? '').trim();
    GiftEvent e;
    if (id == null) {
      e = GiftEvent(
        id: _uuid.v4(),
        name: name.trim(),
        type: type,
        eventDate: eventDate,
        location: loc.isEmpty ? null : loc,
      );
    } else {
      e = events.firstWhere((x) => x.id == id).copyWith(
            name: name.trim(),
            type: type,
            eventDate: eventDate,
            location: loc.isEmpty ? null : loc,
          );
    }
    await _repo.save(e);
    _sync.schedule();
    await load();
    // Sự kiện đầu tiên / vừa tạo tự được chọn làm active.
    if (id == null) await setActive(e.id);
    return e;
  }

  Future<void> setClosed(GiftEvent e, bool closed) async {
    await _repo.save(e.copyWith(status: closed ? 'closed' : 'active'));
    _sync.schedule();
    await load();
  }

  Future<void> delete(GiftEvent e) async {
    await _repo.softDelete(e.id);
    _sync.schedule();
    await load();
  }

  Future<void> refreshTotals() async {
    final m = <String, int>{};
    final all = <String, EventStats>{};
    for (final e in events) {
      final st = await _giftRepo.stats(e.id);
      m[e.id] = st.totalVnd;
      all[e.id] = st;
    }
    totals.assignAll(m);
    statsById.assignAll(all);
  }
}
