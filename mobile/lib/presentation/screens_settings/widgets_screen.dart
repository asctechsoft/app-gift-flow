import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controller/settings_controller.dart';
import '../../services/application/notification_service.dart';
import '../../services/application/surface_updater.dart';
import '../../utils/toast_utils.dart';
import '../../values/app_colors.dart';
import '../common_components/components.dart';

/// Màn "Widget & thông báo": bật thông báo cố định, thêm widget Small/Medium ra màn hình chính.
class WidgetsScreen extends StatelessWidget {
  const WidgetsScreen({super.key});

  Future<void> _toggleNotif(SettingsController s, bool v) async {
    if (v) {
      final ok = await NotificationService.to.requestPermission();
      await s.markNotifPermissionAsked();
      if (!ok) {
        Toast.show('notif_perm_denied'.tr);
        return;
      }
    }
    await s.setStatusNotification(v);
  }

  Future<void> _pin(bool medium) async {
    if (!Platform.isAndroid) {
      Toast.show('widget_manual'.tr);
      return;
    }
    final ok = await Get.find<SurfaceUpdater>().pinWidget(medium: medium);
    Toast.show(ok ? 'widget_pin_sent'.tr : 'widget_manual'.tr);
  }

  @override
  Widget build(BuildContext context) {
    final s = Get.find<SettingsController>();
    return GradientScaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'back'.tr,
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: Get.back,
                  ),
                  Text(
                    'widgets_title'.tr,
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                children: [
                  SoftCard(
                    child: Obx(
                      () => Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'set_status_notif'.tr,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'set_status_notif_sub'.tr,
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: s.statusNotification.value,
                            onChanged: (v) => _toggleNotif(s, v),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'widgets_intro'.tr,
                    style: TextStyle(color: AppColors.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  _sample(
                    title: 'widget_small'.tr,
                    preview: _smallPreview(),
                    onAdd: () => _pin(false),
                  ),
                  const SizedBox(height: 14),
                  _sample(
                    title: 'widget_medium'.tr,
                    preview: _mediumPreview(),
                    onAdd: () => _pin(true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sample({required String title, required Widget preview, required VoidCallback onAdd}) =>
      SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
            const SizedBox(height: 10),
            Center(child: preview),
            const SizedBox(height: 12),
            PrimaryButton(label: 'widget_add'.tr, icon: Icons.add_to_home_screen_rounded, onPressed: onAdd),
          ],
        ),
      );

  static const _grad = LinearGradient(
    colors: [Color(0xFFA06BF3), Color(0xFF7B3FE4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  Widget _smallPreview() => Container(
    width: 150,
    height: 150,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(gradient: _grad, borderRadius: BorderRadius.circular(24)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('GiftFlow', style: TextStyle(color: Colors.white70, fontSize: 12)),
        const Spacer(),
        Text('home_total'.tr, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const FittedBox(
          child: Text('12.500.000đ',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text('notif_act_voice'.tr, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ),
      ],
    ),
  );

  Widget _mediumPreview() => Container(
    width: double.infinity,
    height: 150,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(gradient: _grad, borderRadius: BorderRadius.circular(24)),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Đám cưới A & B', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const Spacer(),
              const FittedBox(
                child: Text('12.500.000đ',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
              ),
              Text('42 ${'kpi_envelopes'.tr.toLowerCase()}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text('notif_act_voice'.tr,
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('notif_next'.tr, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                const Text('🎁 Minh Anh',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                const Text('20/12 · 10:00',
                    style: TextStyle(color: Colors.white, fontSize: 12)),
                const Text('500.000đ',
                    style: TextStyle(color: Color(0xFFB8FFD9), fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
