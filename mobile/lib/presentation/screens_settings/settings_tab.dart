import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../controller/settings_controller.dart';
import '../../services/application/google_auth_service.dart';
import '../../services/application/sync_service.dart';
import '../../services/application/theme_service.dart';
import '../../utils/toast_utils.dart';
import '../../values/app_colors.dart';
import '../../values/route_name.dart';
import '../common_components/components.dart';
import '../common_components/dialogs.dart';
import '../common_components/ui_kit.dart';

/// S12 - Cài đặt: tài khoản, ứng dụng (ghi âm, sao lưu, ngôn ngữ, giao diện), khác.
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
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
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

  Future<void> _logout(SettingsController s) async {
    final ok = await confirmDialog(
      title: 'logout_title'.tr,
      message: 'logout_msg'.tr,
      confirmLabel: 'logout'.tr,
      danger: true,
    );
    if (!ok) return;
    await Get.find<GoogleAuthService>().signOut();
    Toast.show('logout_done'.tr);
  }

  @override
  Widget build(BuildContext context) {
    final s = Get.find<SettingsController>();
    final sync = Get.find<SyncService>();
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 130),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'settings_title'.tr,
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'settings_subtitle'.tr,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const HeaderBadge(main: '⚙️', sub: ['✨', '💜']),
            ],
          ),
          const SizedBox(height: 8),
          _group('settings_account'.tr, Icons.person_outline_rounded),
          Obx(() {
            final name = s.displayName.value.trim();
            final email = s.accountEmail.value;
            final shown = name.isNotEmpty
                ? name
                : (s.isSignedIn ? email.split('@').first : 'guest_account'.tr);
            return SoftCard(
              onTap: () => Get.toNamed(RouteName.profile),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      InitialsAvatar.initials(shown),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shown,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        Text(
                          s.isSignedIn ? email : 'login_google'.tr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                ],
              ),
            );
          }),
          const SizedBox(height: 14),
          _group('settings_app'.tr, Icons.settings_outlined),
          SoftCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                _Row(
                  icon: Icons.notifications_none_rounded,
                  title: 'set_recording'.tr,
                  subtitle: 'set_recording_sub'.tr,
                  onTap: () => Get.toNamed(RouteName.recordingOptions),
                ),
                const _Sep(),
                _Row(
                  icon: Icons.widgets_outlined,
                  title: 'widgets_title'.tr,
                  subtitle: 'widgets_sub'.tr,
                  onTap: () => Get.toNamed(RouteName.widgets),
                ),
                const _Sep(),
                Obx(() {
                  final on = sync.online.value && !sync.serverUnreachable.value;
                  return _Row(
                    icon: Icons.cloud_upload_outlined,
                    title: 'set_backup'.tr,
                    subtitle: 'set_backup_sub'.tr,
                    trailing: StatusPill(
                      label: on ? 'status_on'.tr : 'status_off'.tr,
                      color: on ? AppColors.success : AppColors.warning,
                      bg: on ? AppColors.successBg : AppColors.warningBg,
                    ),
                    onTap: () => Get.toNamed(RouteName.backup),
                  );
                }),
                const _Sep(),
                Obx(
                  () => _Row(
                    icon: Icons.language_rounded,
                    title: 'language'.tr,
                    subtitle: s.locale.value.languageCode == 'vi'
                        ? 'Tiếng Việt'
                        : 'English',
                    onTap: () => _language(s),
                  ),
                ),
                const _Sep(),
                _ThemeRow(s),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _group('settings_other'.tr, Icons.info_outline_rounded),
          SoftCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (_, snap) => _Row(
                    icon: Icons.menu_book_outlined,
                    title: 'set_about'.tr,
                    subtitle: snap.hasData
                        ? '${'version'.tr} ${snap.data!.version}'
                        : '',
                    onTap: () => Get.toNamed(RouteName.about),
                  ),
                ),
                const _Sep(),
                _Row(
                  icon: Icons.star_border_rounded,
                  title: 'set_rate'.tr,
                  subtitle: 'set_rate_sub'.tr,
                  trailing: Icon(
                    Icons.open_in_new_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  onTap: () => Toast.show('set_rate_soon'.tr),
                ),
                const _Sep(),
                _Row(
                  icon: Icons.shield_outlined,
                  title: 'privacy_title'.tr,
                  onTap: () => Get.toNamed(RouteName.privacy),
                ),
                const _Sep(),
                _Row(
                  icon: Icons.description_outlined,
                  title: 'terms_title'.tr,
                  onTap: () => Get.toNamed(RouteName.terms),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Obx(() {
            if (s.isSignedIn) {
              return GestureDetector(
                onTap: () => _logout(s),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: AppColors.dangerBg,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout_rounded, color: AppColors.danger),
                      const SizedBox(width: 8),
                      Text(
                        'logout'.tr,
                        style: TextStyle(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return PrimaryButton(
              label: 'login_google'.tr,
              icon: Icons.login_rounded,
              onPressed: () => Get.toNamed(RouteName.profile),
            );
          }),
        ],
      ),
    );
  }

  Widget _group(String t, IconData i) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Row(
      children: [
        Icon(i, size: 19, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      ],
    ),
  );
}

class _Sep extends StatelessWidget {
  const _Sep();
  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, indent: 62, color: AppColors.border.withValues(alpha: 0.7));
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.chip,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(
                    subtitle!,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[trailing!, const SizedBox(width: 6)],
          Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
        ],
      ),
    ),
  );
}

/// Giao diện: Sáng / Tối / Hệ thống (đổi ngay, lưu lại).
class _ThemeRow extends StatelessWidget {
  const _ThemeRow(this.s);
  final SettingsController s;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.chip,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.phone_iphone_rounded, color: AppColors.primary, size: 21),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            'set_theme'.tr,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
        Obx(
          () => Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.chip,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                _seg(Icons.wb_sunny_outlined, ThemeModeKey.light),
                _seg(Icons.dark_mode_outlined, ThemeModeKey.dark),
                _seg(Icons.desktop_windows_outlined, ThemeModeKey.system),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _seg(IconData i, String mode) {
    final sel = s.themeMode.value == mode;
    return GestureDetector(
      onTap: () async {
        await s.setThemeMode(mode);
        ThemeService.change(mode);
      },
      child: Container(
        width: 34,
        height: 32,
        decoration: BoxDecoration(
          color: sel ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          boxShadow: sel
              ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.15), blurRadius: 6)]
              : null,
        ),
        child: Icon(i, size: 18, color: sel ? AppColors.primary : AppColors.textSecondary),
      ),
    );
  }
}
