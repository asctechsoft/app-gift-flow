import 'dart:async';
import 'dart:io';

import 'package:asc_common/asc_common.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../models/data_models/invitation.dart';
import '../../utils/date_fmt.dart';
import '../../utils/money.dart';

/// Nội dung thông báo trạng thái (thu gọn + mở rộng).
class StatusSnapshot {
  StatusSnapshot({
    required this.title,
    required this.collapsed,
    required this.expanded,
  });

  /// Dòng tiêu đề (tên sự kiện).
  final String title;

  /// Nội dung khi thu gọn (1 dòng): tổng tiền, số phong bì...
  final String collapsed;

  /// Nội dung khi mở rộng (nhiều dòng).
  final String expanded;
}

/// Thông báo native Android:
///  - Trạng thái cố định (ongoing): thu gọn hiện tổng tiền; mở rộng hiện chi tiết + nút
///    Ghi âm / Nhập nhanh / Lịch đi mừng.
///  - Nhắc lịch đi mừng: tối hôm trước + trước giờ diễn ra.
class NotificationService extends GetxService {
  static NotificationService get to => Get.find<NotificationService>();
  static final AscLogger _log = AscLogger();

  static const int statusId = 1001;
  static const int _reminderBase = 100000;

  static const String _statusChannel = 'giftflow_status';
  static const String _reminderChannel = 'giftflow_reminders';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool get ready => _ready;

  /// Hành động chờ xử lý khi app được mở từ thông báo (khởi động nguội).
  String? _pendingRoute;

  /// Router do UI cung cấp (tránh service phụ thuộc màn hình).
  void Function(String route)? onRoute;

  Future<NotificationService> init() async {
    if (!Platform.isAndroid) return this;
    try {
      tzdata.initializeTimeZones();
      // Thị trường Việt Nam: UTC+7 cố định (không có giờ mùa hè).
      tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_gift'),
        ),
        onDidReceiveNotificationResponse: _onResponse,
      );
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        final r = launch!.notificationResponse;
        _pendingRoute = (r?.actionId?.isNotEmpty ?? false) ? r!.actionId : r?.payload;
      }
      _ready = true;
    } catch (e, st) {
      _log.error('notification init failed', e, st);
    }
    return this;
  }

  void _onResponse(NotificationResponse r) {
    final route = (r.actionId?.isNotEmpty ?? false) ? r.actionId! : (r.payload ?? '');
    if (route.isEmpty) return;
    final h = onRoute;
    if (h == null) {
      _pendingRoute = route;
    } else {
      h(route);
    }
  }

  /// Gọi khi UI chính đã sẵn sàng: xử lý hành động từ thông báo đã mở app.
  void flushPendingRoute() {
    final r = _pendingRoute;
    if (r == null) return;
    _pendingRoute = null;
    onRoute?.call(r);
  }

  /// Android 13+ cần xin quyền thông báo. Trả về true nếu được phép.
  Future<bool> requestPermission() async {
    if (!_ready) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission();
      return granted ?? true;
    } catch (_) {
      return false;
    }
  }

  // ------------------------------------------------------ trạng thái cố định

  Future<void> showStatus(StatusSnapshot s) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        statusId,
        s.title,
        s.collapsed,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _statusChannel,
            'status_channel_name'.tr,
            channelDescription: 'status_channel_desc'.tr,
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            autoCancel: false,
            onlyAlertOnce: true,
            showWhen: false,
            silent: true,
            channelShowBadge: false,
            visibility: NotificationVisibility.public,
            category: AndroidNotificationCategory.status,
            icon: 'ic_stat_gift',
            color: const Color(0xFF7837E8),
            styleInformation: BigTextStyleInformation(
              s.expanded,
              contentTitle: s.title,
              summaryText: 'GiftFlow AI',
            ),
            actions: <AndroidNotificationAction>[
              AndroidNotificationAction(
                'voice',
                'notif_act_voice'.tr,
                showsUserInterface: true,
                cancelNotification: false,
              ),
              AndroidNotificationAction(
                'quick',
                'notif_act_quick'.tr,
                showsUserInterface: true,
                cancelNotification: false,
              ),
              AndroidNotificationAction(
                'invitations',
                'notif_act_invitations'.tr,
                showsUserInterface: true,
                cancelNotification: false,
              ),
            ],
          ),
        ),
        payload: 'home',
      );
    } catch (e, st) {
      _log.error('show status failed', e, st);
    }
  }

  Future<void> cancelStatus() async {
    if (!_ready) return;
    try {
      await _plugin.cancel(statusId);
    } catch (_) {}
  }

  // ------------------------------------------------------------- nhắc lịch

  /// Đặt lại toàn bộ nhắc cho các lời mời SẮP TỚI:
  ///  - 20:00 tối hôm trước;
  ///  - ngày diễn ra: trước 2 giờ nếu có giờ, nếu không thì 08:00.
  Future<void> scheduleReminders(List<Invitation> all, {DateTime? now}) async {
    if (!_ready) return;
    try {
      for (final p in await _plugin.pendingNotificationRequests()) {
        if (p.id >= _reminderBase) await _plugin.cancel(p.id);
      }
      final plans = planReminders(all, now ?? DateTime.now());
      for (final r in plans) {
        await _plugin.zonedSchedule(
          r.id,
          r.title,
          r.body,
          tz.TZDateTime.from(r.at, tz.local),
          NotificationDetails(
            android: AndroidNotificationDetails(
              _reminderChannel,
              'reminder_channel_name'.tr,
              channelDescription: 'reminder_channel_desc'.tr,
              importance: Importance.high,
              priority: Priority.high,
              icon: 'ic_stat_gift',
              color: const Color(0xFF7837E8),
              styleInformation: BigTextStyleInformation(r.body),
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: 'invitations',
        );
      }
    } catch (e, st) {
      _log.error('schedule reminders failed', e, st);
    }
  }

  /// Tính các lần nhắc (thuần, test được).
  static List<ReminderPlan> planReminders(List<Invitation> all, DateTime now) {
    final out = <ReminderPlan>[];
    for (final i in all) {
      if (!i.isUpcoming) continue;
      final when = i.when;
      if (when == null) continue;
      final base = _reminderBase + (i.id.hashCode & 0x7fffff) * 2;
      final where = (i.location ?? '').trim();
      final amount = i.plannedVnd > 0 ? ' · ${'notif_planned'.tr} ${Money.format(i.plannedVnd)}' : '';
      final timeStr = i.eventTime == null ? '' : ' ${i.eventTime}';
      final detail =
          '${i.personName} · ${DateFmt.display(i.eventDate)}$timeStr${where.isEmpty ? '' : ' · $where'}$amount';

      // 1) 20:00 tối hôm trước
      final eve = DateTime(when.year, when.month, when.day - 1, 20);
      if (eve.isAfter(now)) {
        out.add(ReminderPlan(base, eve, 'notif_remind_tomorrow'.tr, detail));
      }
      // 2) Ngày diễn ra: trước 2 giờ nếu có giờ, không thì 08:00
      final day = i.eventTime == null
          ? DateTime(when.year, when.month, when.day, 8)
          : when.subtract(const Duration(hours: 2));
      if (day.isAfter(now)) {
        out.add(
          ReminderPlan(
            base + 1,
            day,
            i.eventTime == null ? 'notif_remind_today'.tr : 'notif_remind_soon'.tr,
            detail,
          ),
        );
      }
    }
    return out;
  }
}

class ReminderPlan {
  ReminderPlan(this.id, this.at, this.title, this.body);
  final int id;
  final DateTime at;
  final String title;
  final String body;
}
