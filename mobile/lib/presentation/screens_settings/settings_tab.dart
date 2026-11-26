import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controller/settings_controller.dart';
import '../../values/app_colors.dart';
import '../../values/route_name.dart';
import '../common_components/components.dart';

/// S12 - Cài đặt / Cá nhân.
class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  Future<void> _language(SettingsController s) async {
    await Get.bottomSheet<void>(
      SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'language'.tr,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            for (final l in const [
              (Locale('vi', 'VN'), 'Tiếng Việt'),
              (Locale('en', 'US'), 'English'),
            ])
              ListTile(
                title: Text(l.$2),
                trailing: s.locale.value.languageCode == l.$1.languageCode
                    ? const Icon(Icons.check_rounded, color: AppColors.primary)
                    : null,
                onTap: () async {
                  await s.setLanguage(l.$1);
                  Get.back();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
      backgroundColor: AppColors.surface,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = Get.find<SettingsController>();
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 130),
        children: [
          Text(
            'settings_title'.tr,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          Obx(
            () => _Tile(
              icon: s.isSignedIn
                  ? Icons.verified_user_rounded
                  : Icons.person_outline_rounded,
              title: 'set_profile'.tr,
              subtitle: s.isSignedIn ? s.accountEmail.value : 'login_google'.tr,
              onTap: () => Get.toNamed(RouteName.profile),
            ),
          ),
          _Tile(
            icon: Icons.mic_none_rounded,
            title: 'set_recording'.tr,
            onTap: () => Get.toNamed(RouteName.recordingOptions),
          ),
          _Tile(
            icon: Icons.cloud_upload_outlined,
            title: 'set_backup'.tr,
            onTap: () => Get.toNamed(RouteName.backup),
          ),
          Obx(
            () => _Tile(
              icon: Icons.language_rounded,
              title: 'language'.tr,
              subtitle: s.locale.value.languageCode == 'vi'
                  ? 'Tiếng Việt'
                  : 'English',
              onTap: () => _language(s),
            ),
          ),
          _Tile(
            icon: Icons.info_outline_rounded,
            title: 'set_about'.tr,
            onTap: () => Get.toNamed(RouteName.about),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: SoftCard(
          onTap: onTap,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondary),
            ],
          ),
        ),
      );
}
