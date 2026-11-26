import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../models/data_models/plan_models.dart';
import '../repository/plan_repository.dart';
import '../services/application/sync_service.dart';
import 'event_controller.dart';

/// Kế hoạch của MỘT sự kiện đang mở: khoản chi (ngân sách) + khách mời dự kiến.
/// Không liên quan tiền mừng. Ghi local trước, đồng bộ qua outbox.
class PlanController extends GetxController {
  PlanController(this._repo, this._events, this._sync);

  final PlanRepository _repo;
  final EventController _events;
  final SyncService _sync;
  static const _uuid = Uuid();

  final RxnString eventId = RxnString();
  final RxList<PlanItem> items = <PlanItem>[].obs;

  /// Khách đã lọc (hiển thị trong danh sách).
  final RxList<PlanGuest> guests = <PlanGuest>[].obs;
  final Rx<PlanSummary> summary = PlanSummary.compute(
    budgetVnd: null,
    items: const [],
    guests: const [],
  ).obs;

  final RxString guestQuery = ''.obs;
  final RxnString guestSide = RxnString();
  final RxnString guestStatus = RxnString();
  final RxBool loading = false.obs;

  @override
  void onInit() {
    super.onInit();
    ever(_sync.dataVersion, (_) => reload());
    ever(_events.events, (_) => reload());
    debounce(guestQuery, (_) => reload(), time: const Duration(milliseconds: 220));
    ever(guestSide, (_) => reload());
    ever(guestStatus, (_) => reload());
  }

  Future<void> open(String id) async {
    eventId.value = id;
    guestQuery.value = '';
    guestSide.value = null;
    guestStatus.value = null;
    await reload();
  }

  int? get budgetVnd =>
      _events.events.firstWhereOrNull((e) => e.id == eventId.value)?.budgetVnd;

  Future<void> reload() async {
    final id = eventId.value;
    if (id == null) return;
    loading.value = true;
    try {
      final list = await _repo.items(id);
      final all = await _repo.guests(id);
      final shown = (guestQuery.value.isEmpty &&
              guestSide.value == null &&
              guestStatus.value == null)
          ? all
          : await _repo.guests(
              id,
              query: guestQuery.value,
              side: guestSide.value,
              status: guestStatus.value,
            );
      items.assignAll(list);
      guests.assignAll(shown);
      summary.value = PlanSummary.compute(
        budgetVnd: budgetVnd,
        items: list,
        guests: all,
      );
    } finally {
      loading.value = false;
    }
  }

  void _changed() {
    _sync.schedule();
    reload();
  }

  // ------------------------------------------------------------- ngân sách

  Future<void> setBudget(int? v) async {
    final id = eventId.value;
    if (id == null) return;
    await _events.setBudget(id, (v == null || v <= 0) ? null : v);
    await reload();
  }

  PlanItem newItem({
    required String category,
    required String name,
    int planned = 0,
    int paid = 0,
    String? vendor,
    String? dueDate,
    String? note,
  }) => PlanItem(
    id: _uuid.v4(),
    eventId: eventId.value!,
    category: category,
    name: name.trim(),
    plannedVnd: planned,
    paidVnd: paid,
    status: PayStatus.derive(planned, paid),
    vendor: _clean(vendor),
    dueDate: dueDate,
    note: _clean(note),
  );

  Future<void> saveItem(PlanItem i) async {
    final fixed = i.copyWith(
      status: PayStatus.derive(i.plannedVnd, i.paidVnd),
      vendor: _clean(i.vendor),
      note: _clean(i.note),
    );
    await _repo.saveItem(fixed);
    _changed();
  }

  Future<void> deleteItem(String id) async {
    await _repo.deleteItem(id);
    _changed();
  }

  Future<void> undoDeleteItem(String id) async {
    await _repo.restoreItem(id);
    _changed();
  }

  /// Thêm các khoản mẫu của kế hoạch cưới (chi phí để trống, người dùng tự điền).
  /// Bỏ qua khoản đã có cùng danh mục + tên. Trả số khoản đã thêm.
  Future<int> applyWeddingTemplate() async {
    final id = eventId.value;
    if (id == null) return 0;
    // Đọc lại từ DB (không dùng danh sách đang hiện, có thể chưa kịp cập nhật).
    final current = await _repo.items(id);
    final existing = current.map((i) => '${i.category}|${i.name.toLowerCase()}').toSet();
    final add = <PlanItem>[];
    for (final (cat, key) in PlanTemplate.wedding) {
      final name = key.tr;
      if (existing.contains('$cat|${name.toLowerCase()}')) continue;
      add.add(newItem(category: cat, name: name));
    }
    if (add.isEmpty) return 0;
    await _repo.saveItems(add);
    _changed();
    return add.length;
  }

  // ---------------------------------------------------------------- khách

  PlanGuest newGuest({
    required String name,
    String? relationship,
    String side = 'mine',
    int partySize = 1,
    String status = InviteStatus.planned,
    String? phone,
    String? note,
  }) => PlanGuest(
    id: _uuid.v4(),
    eventId: eventId.value!,
    name: name.trim(),
    relationship: _clean(relationship),
    side: side,
    partySize: partySize < 1 ? 1 : partySize,
    inviteStatus: status,
    phone: _clean(phone),
    note: _clean(note),
  );

  Future<void> saveGuest(PlanGuest g) async {
    await _repo.saveGuest(
      g.copyWith(
        name: g.name.trim(),
        partySize: g.partySize < 1 ? 1 : g.partySize,
        relationship: _clean(g.relationship),
        phone: _clean(g.phone),
        note: _clean(g.note),
      ),
    );
    _changed();
  }

  Future<void> setInviteStatus(PlanGuest g, String status) async {
    if (g.inviteStatus == status) return;
    await _repo.saveGuest(g.copyWith(inviteStatus: status));
    _changed();
  }

  Future<void> deleteGuest(String id) async {
    await _repo.deleteGuest(id);
    _changed();
  }

  Future<void> undoDeleteGuest(String id) async {
    await _repo.restoreGuest(id);
    _changed();
  }

  /// Dán nhiều khách: mỗi dòng "Tên - quan hệ - số người" (quan hệ, số người không bắt buộc).
  /// Bỏ dòng trống và tên đã có (không phân biệt hoa thường). Trả số khách đã thêm.
  Future<int> addGuestsFromText(String text, {required String side}) async {
    final id = eventId.value;
    if (id == null) return 0;
    final parsed = parseGuestLines(text);
    final all = await _repo.guests(id);
    final have = all.map((g) => g.name.trim().toLowerCase()).toSet();
    final add = <PlanGuest>[];
    for (final p in parsed) {
      final k = p.name.toLowerCase();
      if (have.contains(k)) continue;
      have.add(k);
      add.add(
        newGuest(
          name: p.name,
          relationship: p.relationship,
          side: side,
          partySize: p.partySize,
        ),
      );
    }
    if (add.isEmpty) return 0;
    await _repo.saveGuests(add);
    _changed();
    return add.length;
  }

  static String? _clean(String? s) {
    final t = (s ?? '').trim();
    return t.isEmpty ? null : t;
  }
}

class ParsedGuestLine {
  ParsedGuestLine(this.name, this.relationship, this.partySize);
  final String name;
  final String? relationship;
  final int partySize;
}

/// "Anh Long - Bạn thân - 2", "Cô Lan, đồng nghiệp", "Bác Hùng" -> danh sách dòng hợp lệ.
List<ParsedGuestLine> parseGuestLines(String text) {
  final out = <ParsedGuestLine>[];
  for (final raw in text.split(RegExp(r'[\r\n]+'))) {
    final line = raw.trim().replaceFirst(RegExp(r'^[\-\*•\d\.\)\s]+(?=\p{L})', unicode: true), '');
    if (line.isEmpty) continue;
    final parts = line
        .split(RegExp(r'\s*[-–—,;|]\s*'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) continue;
    final name = parts.first;
    String? rel;
    var party = 1;
    for (final p in parts.skip(1)) {
      final n = int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), ''));
      if (n != null && RegExp(r'^\d+\s*(người|nguoi|ng|pax|person|people)?$', caseSensitive: false).hasMatch(p)) {
        party = n.clamp(1, 50);
      } else if (rel == null) {
        rel = p;
      }
    }
    out.add(ParsedGuestLine(name, rel, party));
  }
  return out;
}
