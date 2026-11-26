import 'dart:async';
import 'dart:io';

import 'package:asc_common/asc_common.dart';
import 'package:get/get.dart';
import 'package:home_widget/home_widget.dart';

import '../../controller/event_controller.dart';
import '../../controller/gift_controller.dart';
import '../../controller/invitation_controller.dart';
import '../../controller/settings_controller.dart';
import '../../models/data_models/gift_event.dart';
import '../../models/data_models/invitation.dart';
import '../../repository/gift_repository.dart';
import '../../utils/date_fmt.dart';
import '../../utils/money.dart';
import 'notification_service.dart';

/// Dữ liệu tóm tắt dùng chung cho thông báo cố định + widget màn hình chính.
class SurfaceSnapshot {
  SurfaceSnapshot({
    required this.eventName,
    required this.totalVnd,
    required this.envelopes,
    required this.guests,
    required this.pending,
    required this.todayVnd,
    required this.top,
    this.next,
    this.nextDaysLeft,
  });

  final String eventName; // rỗng = chưa có sự kiện
  final int totalVnd;
  final int envelopes;
  final int guests;
  final int pending;
  final int todayVnd;
  final List<GuestStat> top;
  final Invitation? next;
  final int? nextDaysLeft;

  bool get hasEvent => eventName.isNotEmpty;

  String get nextWhen {
    final n = next;
    if (n == null) return '';
    final d = DateTime.tryParse(n.eventDate);
    final date = d == null ? n.eventDate : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    final t = n.eventTime == null ? '' : ' · ${n.eventTime}';
    final left = nextDaysLeft;
    final lbl = left == null
        ? ''
        : (left == 0 ? ' · ${'inv_today'.tr}' : ' · ${'inv_days_left'.trParams({'args1': '$left'})}');
    return '$date$t$lbl';
  }

  /// Thông báo cố định: nội dung thu gọn (1 dòng).
  String get collapsedText {
    if (!hasEvent) return 'notif_no_event'.tr;
    return '${Money.format(totalVnd)} · $envelopes ${'kpi_envelopes'.tr.toLowerCase()} · $guests ${'kpi_guests'.tr.toLowerCase()}';
  }

  /// Thông báo cố định: nội dung mở rộng (nhiều dòng).
  String get expandedText {
    if (!hasEvent) return 'notif_no_event_long'.tr;
    final l = <String>[
      '${'home_total'.tr}: ${Money.format(totalVnd)}',
      '${'kpi_envelopes'.tr}: $envelopes · ${'kpi_guests'.tr}: $guests',
      if (todayVnd > 0) '${'notif_today'.tr}: +${Money.format(todayVnd)}',
      if (pending > 0) '${'notif_pending'.tr}: $pending',
      if (top.isNotEmpty)
        '${'top_givers'.tr}: ${top.take(3).map((g) => '${g.name} ${Money.format(g.totalVnd)}').join(' · ')}',
      if (next != null) '${'notif_next'.tr}: ${next!.personName} · $nextWhen${next!.plannedVnd > 0 ? ' · ${Money.format(next!.plannedVnd)}' : ''}',
    ];
    return l.join('\n');
  }
}

/// Cập nhật thông báo cố định và widget mỗi khi dữ liệu đổi (gộp trong 1 giây).
class SurfaceUpdater extends GetxService {
  SurfaceUpdater(this._events, this._gifts, this._invites, this._settings, this._giftRepo);

  final EventController _events;
  final GiftController _gifts;
  final InvitationController _invites;
  final SettingsController _settings;
  final GiftRepository _giftRepo;
  static final AscLogger _log = AscLogger();

  Timer? _debounce;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    ever(_gifts.stats, (_) => schedule());
    ever(_gifts.todayVnd, (_) => schedule());
    ever(_events.active, (_) => schedule());
    ever(_invites.stats, (_) => schedule());
    ever(_settings.statusNotification, (_) => schedule());
    schedule();
  }

  void schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 1), refresh);
  }

  Future<SurfaceSnapshot> snapshot() async {
    final GiftEvent? ev = _events.active.value;
    final st = _gifts.stats.value;
    var top = const <GuestStat>[];
    if (ev != null) {
      try {
        top = (await _giftRepo.stats(ev.id)).topGuests;
      } catch (_) {}
    }
    final now = DateTime.now();
    final n = _invites.stats.value.next;
    return SurfaceSnapshot(
      eventName: ev?.name ?? '',
      totalVnd: st.totalVnd,
      envelopes: st.envelopes,
      guests: st.guests,
      pending: st.pendingCount,
      todayVnd: _gifts.todayVnd.value,
      top: top,
      next: n,
      nextDaysLeft: n?.daysUntil(now),
    );
  }

  Future<void> refresh() async {
    if (!Platform.isAndroid) return;
    final s = await snapshot();
    await _updateNotification(s);
    await _updateWidgets(s);
  }

  Future<void> _updateNotification(SurfaceSnapshot s) async {
    final ns = NotificationService.to;
    if (!_settings.statusNotification.value) {
      await ns.cancelStatus();
      return;
    }
    await ns.showStatus(
      StatusSnapshot(
        title: s.hasEvent ? 'GiftFlow · ${s.eventName}' : 'GiftFlow AI',
        collapsed: s.collapsedText,
        expanded: s.expandedText,
      ),
    );
  }

  static const _small = 'com.asc.gift_flow.widget.SmallWidgetProvider';
  static const _medium = 'com.asc.gift_flow.widget.MediumWidgetProvider';

  Future<void> _updateWidgets(SurfaceSnapshot s) async {
    try {
      Future<void> put(String k, String v) => HomeWidget.saveWidgetData<String>(k, v);
      await put('w_event', s.hasEvent ? s.eventName : 'GiftFlow AI');
      await put('w_total', s.hasEvent ? Money.format(s.totalVnd) : '—');
      await put('w_env', '${s.envelopes}');
      await put('w_guests', '${s.guests}');
      await put('w_env_label', 'kpi_envelopes'.tr);
      await put('w_guests_label', 'kpi_guests'.tr);
      await put('w_today', s.todayVnd > 0 ? '+${Money.format(s.todayVnd)}' : '');
      await put('w_hint', s.hasEvent ? 'widget_tap_voice'.tr : 'widget_create_event'.tr);
      await put('w_top_title', 'top_givers'.tr);
      for (var i = 0; i < 3; i++) {
        await put(
          'w_top${i + 1}',
          i < s.top.length ? '${i + 1}. ${s.top[i].name} · ${Money.format(s.top[i].totalVnd)}' : '',
        );
      }
      await put('w_next_title', s.next == null ? 'widget_no_invite'.tr : '🎁 ${s.next!.personName}');
      await put('w_next_when', s.next == null ? '' : s.nextWhen);
      await put(
        'w_next_amount',
        s.next != null && s.next!.plannedVnd > 0 ? Money.format(s.next!.plannedVnd) : '',
      );
      await put('w_btn_voice', 'notif_act_voice'.tr);
      await put('w_btn_quick', 'notif_act_quick'.tr);
      await HomeWidget.updateWidget(qualifiedAndroidName: _small);
      await HomeWidget.updateWidget(qualifiedAndroidName: _medium);
    } catch (e, st) {
      _log.error('update widgets failed', e, st);
    }
  }

  /// Thêm widget ra màn hình chính (Android 8+ và launcher hỗ trợ). false = phải thêm thủ công.
  Future<bool> pinWidget({required bool medium}) async {
    try {
      final ok = await HomeWidget.isRequestPinWidgetSupported() ?? false;
      if (!ok) return false;
      await HomeWidget.requestPinWidget(qualifiedAndroidName: medium ? _medium : _small);
      await refresh();
      return true;
    } catch (e, st) {
      _log.error('pin widget failed', e, st);
      return false;
    }
  }

  /// "dd/MM" cho giao diện (dùng chung nơi khác).
  static String shortDate(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? DateFmt.display(iso) : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  }
}
