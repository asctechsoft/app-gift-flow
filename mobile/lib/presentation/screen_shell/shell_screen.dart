import 'package:flutter/material.dart';
import 'dart:io';

import 'package:get/get.dart';
import 'package:home_widget/home_widget.dart';

import '../../controller/event_controller.dart';
import '../../controller/gift_controller.dart';
import '../../controller/settings_controller.dart';
import '../../services/application/notification_service.dart';
import '../../services/application/surface_updater.dart';
import '../../utils/toast_utils.dart';
import '../../values/app_colors.dart';
import '../../values/route_name.dart';
import '../common_components/floating_mic_nav.dart';
import '../screen_events/events_tab.dart';
import '../screen_gifts/gifts_tab.dart';
import '../screen_home/home_tab.dart';
import '../screens_settings/settings_tab.dart';

class ShellController extends GetxController {
  final RxInt index = 0.obs;
  void go(int i) => index.value = i;

  bool _attached = false;

  /// Gắn router thông báo + khởi động thông báo cố định/widget (một lần, khi shell hiện).
  void attach() {
    if (_attached) return;
    _attached = true;
    final ns = NotificationService.to;
    ns.onRoute = _route;
    ns.flushPendingRoute();
    Get.find<SurfaceUpdater>().start();
    if (Platform.isAndroid) {
      HomeWidget.initiallyLaunchedFromHomeWidget().then((u) {
        if (u != null) _route(u.host);
      });
      HomeWidget.widgetClicked.listen((u) {
        if (u != null) _route(u.host);
      });
    }
    _askPermission();
  }

  Future<void> _askPermission() async {
    final s = Get.find<SettingsController>();
    if (s.notifPermissionAsked) return;
    await s.markNotifPermissionAsked();
    final ok = await NotificationService.to.requestPermission();
    if (!ok) await s.setStatusNotification(false);
    Get.find<SurfaceUpdater>().schedule();
  }

  void _route(String r) {
    switch (r) {
      case 'voice':
        final ev = Get.find<EventController>().active.value;
        if (ev == null || ev.isClosed) {
          index.value = 0;
        } else {
          Get.toNamed(RouteName.recording);
        }
      case 'quick':
        final ev = Get.find<EventController>().active.value;
        if (ev == null || ev.isClosed) {
          index.value = 0;
        } else {
          Get.toNamed(RouteName.giftEdit);
        }
      case 'invitations':
        Get.toNamed(RouteName.invitations);
      default:
        index.value = 0;
    }
  }
}

/// Khung điều hướng top-level: chỉ các màn này mới có navbar (BR: màn voice
/// fullscreen không navbar).
class ShellScreen extends StatelessWidget {
  const ShellScreen({super.key});

  Future<void> _openMic() async {
    final events = Get.find<EventController>();
    final ev = events.active.value;
    if (ev == null) {
      Toast.show('need_event_first'.tr);
      Get.toNamed(RouteName.eventEdit, arguments: {'first': true});
      return;
    }
    if (ev.isClosed) {
      Toast.show('event_closed_no_record'.tr);
      return;
    }
    Get.toNamed(RouteName.recording);
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.find<ShellController>();
    Get.find<GiftController>(); // đảm bảo đã khởi tạo
    WidgetsBinding.instance.addPostFrameCallback((_) => c.attach());
    return Obx(
      () => Container(
        decoration: BoxDecoration(gradient: AppColors.screenGradient),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: true,
          body: IndexedStack(
            index: c.index.value,
            children: const [HomeTab(), EventsTab(), GiftsTab(), SettingsTab()],
          ),
          bottomNavigationBar: FloatingMicNav(
            index: c.index.value,
            onTab: c.go,
            onMic: _openMic,
          ),
        ),
      ),
    );
  }
}
