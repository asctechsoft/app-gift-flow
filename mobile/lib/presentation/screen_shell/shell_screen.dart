import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controller/event_controller.dart';
import '../../controller/gift_controller.dart';
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
    return Obx(
      () => Container(
        decoration: const BoxDecoration(gradient: AppColors.screenGradient),
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
