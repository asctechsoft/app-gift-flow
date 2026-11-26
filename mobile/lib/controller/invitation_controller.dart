import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../models/data_models/invitation.dart';
import '../repository/invitation_repository.dart';
import '../services/application/notification_service.dart';
import '../services/application/sync_service.dart';

/// Lịch đi mừng: danh sách lời mời + phân tích + nhắc lịch.
class InvitationController extends GetxController {
  InvitationController(this._repo, this._sync);

  final InvitationRepository _repo;
  final SyncService _sync;
  static const _uuid = Uuid();

  final RxList<Invitation> all = <Invitation>[].obs;
  final Rx<InvitationStats> stats = InvitationStats.compute(
    const [],
    DateTime.now(),
  ).obs;

  /// upcoming | attended | skipped | all
  final RxString filter = 'upcoming'.obs;
  final RxBool loaded = false.obs;

  @override
  void onInit() {
    super.onInit();
    ever(_sync.dataVersion, (_) => load());
    load();
  }

  /// Danh sách theo bộ lọc hiện tại (sắp tới: tăng dần; đã đi/bỏ qua/tất cả: mới nhất trước).
  List<Invitation> get visible {
    final f = filter.value;
    final l = all.where((i) => f == 'all' || i.status == f).toList();
    if (f == 'upcoming') return l;
    return l.reversed.toList();
  }

  int count(String f) =>
      f == 'all' ? all.length : all.where((i) => i.status == f).length;

  Future<void> load() async {
    final list = await _repo.all();
    all.assignAll(list);
    stats.value = InvitationStats.compute(list, DateTime.now());
    loaded.value = true;
    // Đặt lại nhắc mỗi khi dữ liệu đổi (không chặn UI).
    NotificationService.to.scheduleReminders(list);
  }

  Invitation newInvitation({
    required String personName,
    required String eventDate,
    String? relationship,
    String occasion = 'wedding',
    String? eventTime,
    String? location,
    int plannedVnd = 0,
    String? note,
  }) => Invitation(
    id: _uuid.v4(),
    personName: personName.trim(),
    relationship: _clean(relationship),
    occasion: occasion,
    eventDate: eventDate,
    eventTime: eventTime,
    location: _clean(location),
    plannedVnd: plannedVnd,
    note: _clean(note),
  );

  Future<void> save(Invitation i) async {
    await _repo.save(
      i.copyWith(
        personName: i.personName.trim(),
        relationship: _clean(i.relationship),
        location: _clean(i.location),
        note: _clean(i.note),
      ),
    );
    _sync.schedule();
    await load();
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    _sync.schedule();
    await load();
  }

  Future<void> undoDelete(String id) async {
    await _repo.restore(id);
    _sync.schedule();
    await load();
  }

  /// Đánh dấu đã đi + số tiền đã mừng thực tế.
  Future<void> markAttended(Invitation i, int givenVnd) => save(
    i.copyWith(status: InviteState.attended, givenVnd: givenVnd),
  );

  Future<void> markSkipped(Invitation i) =>
      save(i.copyWith(status: InviteState.skipped));

  Future<void> reopen(Invitation i) =>
      save(i.copyWith(status: InviteState.upcoming));

  static String? _clean(String? s) {
    final t = (s ?? '').trim();
    return t.isEmpty ? null : t;
  }
}
