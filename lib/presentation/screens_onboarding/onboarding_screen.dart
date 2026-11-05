import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controller/event_controller.dart';
import '../../controller/settings_controller.dart';
import '../../values/app_assets.dart';
import '../../values/app_colors.dart';
import '../../values/route_name.dart';
import '../common_components/components.dart';

/// S01-S03 - 3 trang onboarding. Không xin quyền micro ở đây.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pc = PageController();
  int _page = 0;

  static const _pages = [
    (AppAssets.onboarding1, 'onb1_title', 'onb1_desc'),
    (AppAssets.onboarding2, 'onb2_title', 'onb2_desc'),
    (AppAssets.onboarding3, 'onb3_title', 'onb3_desc'),
  ];

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await Get.find<SettingsController>().markOnboardingSeen();
    if (Get.find<EventController>().events.isEmpty) {
      Get.offAllNamed(RouteName.eventEdit, arguments: {'first': true});
    } else {
      Get.offAllNamed(RouteName.shell);
    }
  }

  void _next() {
    if (_page >= _pages.length - 1) {
      _finish();
    } else {
      _pc.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _pages.length - 1;
    return GradientScaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: AnimatedOpacity(
                opacity: last ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                child: TextButton(
                  onPressed: last ? null : _finish,
                  style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
                  child: Text(
                    'skip'.tr,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pc,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) {
                  final p = _pages[i];
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        Image.asset(p.$1, height: 280, fit: BoxFit.contain),
                        const SizedBox(height: 28),
                        Text(
                          p.$2.tr,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          p.$3.tr,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.45,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _page ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page ? AppColors.primary : AppColors.border,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
              child: PrimaryButton(
                label: last ? 'start'.tr : 'next'.tr,
                onPressed: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
