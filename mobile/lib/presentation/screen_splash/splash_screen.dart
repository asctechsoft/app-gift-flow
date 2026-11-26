import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controller/event_controller.dart';
import '../../controller/settings_controller.dart';
import '../../services/application/sync_service.dart';
import '../../values/app_assets.dart';
import '../../values/app_colors.dart';
import '../../values/route_name.dart';
import '../common_components/components.dart';

/// S00 - Splash: khởi tạo DB local, kiểm tra onboarding/sự kiện rồi điều hướng.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final started = DateTime.now();
    final events = Get.find<EventController>();
    await events.load();
    // Đẩy outbox còn tồn (nếu có mạng) - không chặn khởi động.
    Get.find<SyncService>().sync();
    final left =
        const Duration(milliseconds: 1400) - DateTime.now().difference(started);
    if (left > Duration.zero) await Future<void>.delayed(left);

    final settings = Get.find<SettingsController>();
    if (!settings.onboardingSeen) {
      Get.offAllNamed(RouteName.onboarding);
    } else if (events.events.isEmpty) {
      // Flow A: chưa có event -> tạo sự kiện đầu tiên.
      Get.offAllNamed(RouteName.eventEdit, arguments: {'first': true});
    } else {
      Get.offAllNamed(RouteName.shell);
    }
  }

  @override
  Widget build(BuildContext context) => GradientScaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(AppAssets.logo, width: 132, height: 132),
                const SizedBox(height: 14),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'GiftFlow',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'AI',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'splash_tagline'.tr,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                SizedBox(
                  width: 56,
                  child: ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                    child: LinearProgressIndicator(
                      minHeight: 4,
                      color: AppColors.primary,
                      backgroundColor: AppColors.chip,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
