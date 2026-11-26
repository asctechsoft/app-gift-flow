import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../controller/settings_controller.dart';
import '../../services/application/api_client.dart';
import '../../services/application/google_auth_service.dart';
import '../../services/application/sync_service.dart';
import '../../utils/date_fmt.dart';
import '../../utils/toast_utils.dart';
import '../../values/app_assets.dart';
import '../../values/app_colors.dart';
import '../common_components/components.dart';
import '../common_components/dialogs.dart';

/// Thông tin cá nhân (tên hiển thị dùng ở lời chào Home).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SettingsController s = Get.find<SettingsController>();
  late final TextEditingController _name = TextEditingController(
    text: s.displayName.value,
  );
  final GoogleAuthService _auth = Get.find<GoogleAuthService>();
  bool _busy = false;

  Future<void> _signIn() async {
    setState(() => _busy = true);
    try {
      await _auth.signIn();
      _name.text = s.displayName.value;
      Toast.show('login_done'.tr);
    } on GoogleAuthException catch (e) {
      if (e.code == 'not_configured') {
        Toast.show('login_not_configured'.tr);
      } else if (e.code != 'cancelled') {
        Toast.show('login_failed'.tr);
      }
    } on NetworkException {
      Toast.show('err_network'.tr);
    } on ApiException catch (e) {
      Toast.show(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    final ok = await confirmDialog(
      title: 'logout_title'.tr,
      message: 'logout_msg'.tr,
      confirmLabel: 'logout'.tr,
      danger: true,
    );
    if (ok) await _auth.signOut();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GradientScaffold(
        appBar: AppHeader(title: 'set_profile'.tr),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Obx(
                  () => SoftCard(
                    child: s.isSignedIn
                        ? Row(
                            children: [
                              const Icon(Icons.verified_user_rounded,
                                  color: AppColors.success),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('login_signed_in'.tr,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800)),
                                    Text(s.accountEmail.value,
                                        style: const TextStyle(
                                            color: AppColors.textSecondary)),
                                  ],
                                ),
                              ),
                              TextButton(
                                  onPressed: _signOut,
                                  child: Text('logout'.tr)),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('login_title'.tr,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Text('login_desc'.tr,
                                  style: const TextStyle(
                                      color: AppColors.textSecondary)),
                              const SizedBox(height: 12),
                              SecondaryButton(
                                label: 'login_google'.tr,
                                icon: Icons.login_rounded,
                                onPressed: _busy ? null : _signIn,
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                FieldLabel('profile_name'.tr),
                IconField(
                  controller: _name,
                  icon: Icons.person_outline_rounded,
                  hint: 'profile_name_hint'.tr,
                ),
                const SizedBox(height: 10),
                Text(
                  'profile_note'.tr,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const Spacer(),
                PrimaryButton(
                  label: 'save'.tr,
                  onPressed: () async {
                    await s.setDisplayName(_name.text);
                    Toast.show('saved'.tr);
                    Get.back();
                  },
                ),
              ],
            ),
          ),
        ),
      );
}

/// Tùy chọn ghi âm: tự cắt phong bì khi im lặng, độ nhạy.
class RecordingOptionsScreen extends StatelessWidget {
  const RecordingOptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Get.find<SettingsController>();
    return GradientScaffold(
      appBar: AppHeader(title: 'set_recording'.tr),
      body: SafeArea(
        child: Obx(
          () => ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            children: [
              SoftCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: SwitchListTile(
                  value: s.autoSilenceCut.value,
                  activeThumbColor: AppColors.primary,
                  title: Text('rec_opt_auto'.tr),
                  subtitle: Text('rec_opt_auto_note'.tr),
                  onChanged: s.setAutoSilenceCut,
                ),
              ),
              const SizedBox(height: 12),
              SoftCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: SwitchListTile(
                  value: s.autoSave.value,
                  activeThumbColor: AppColors.primary,
                  title: Text('rec_opt_autosave'.tr),
                  subtitle: Text('rec_opt_autosave_note'.tr),
                  onChanged: s.setAutoSave,
                ),
              ),
              const SizedBox(height: 12),
              SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'rec_opt_silence'.trParams({
                        'args1': (s.silenceMs.value / 1000).toStringAsFixed(1),
                      }),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Slider(
                      value: s.silenceMs.value.toDouble(),
                      min: 2000,
                      max: 8000,
                      divisions: 12,
                      activeColor: AppColors.primary,
                      onChanged: s.autoSilenceCut.value
                          ? (v) => s.setSilenceMs(v.round())
                          : null,
                    ),
                    Text(
                      'rec_opt_silence_note'.tr,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ErrorBanner(
                message: 'rec_opt_privacy'.tr,
                icon: Icons.privacy_tip_outlined,
                warning: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// X07 - Sao lưu & đồng bộ: trạng thái outbox, quota AI, khôi phục.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final SyncService sync = Get.find<SyncService>();
  final ApiClient api = Get.find<ApiClient>();
  Map<String, dynamic>? _me;
  String? _meError;
  bool _restoring = false;
  late final TextEditingController _urlCtl =
      TextEditingController(text: ApiClient.baseUrl);
  bool _checking = false;

  Future<void> _saveAndCheck() async {
    setState(() => _checking = true);
    await api.setBaseUrl(_urlCtl.text);
    _urlCtl.text = ApiClient.baseUrl;
    final ok = await api.ping();
    Toast.show(ok ? 'server_ok'.tr : 'server_fail'.tr);
    if (ok) {
      await sync.sync(force: true);
      _loadMe();
    }
    if (mounted) setState(() => _checking = false);
  }

  @override
  void initState() {
    super.initState();
    _loadMe();
  }

  Future<void> _loadMe() async {
    try {
      final m = await api.me();
      if (mounted) setState(() => _me = m);
    } on NetworkException {
      if (mounted) setState(() => _meError = 'err_network'.tr);
    } on ApiException catch (e) {
      if (mounted) setState(() => _meError = e.message);
    }
  }

  Future<void> _restore() async {
    final ok = await confirmDialog(
      title: 'restore_title'.tr,
      message: 'restore_msg'.tr,
      confirmLabel: 'restore'.tr,
    );
    if (!ok) return;
    setState(() => _restoring = true);
    try {
      final n = await sync.restoreFromServer();
      Toast.show('restore_done'.trParams({'args1': '$n'}));
    } on NetworkException {
      Toast.show('err_network'.tr);
    } on ApiException catch (e) {
      Toast.show(e.message);
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quota = (_me?['quota'] as Map?)?.cast<String, dynamic>();
    return GradientScaffold(
      appBar: AppHeader(title: 'set_backup'.tr),
      body: SafeArea(
        child: Obx(() {
          final pending = sync.pendingCount.value;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            children: [
              if (!sync.online.value)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child:
                      ErrorBanner(message: 'offline_badge'.tr, warning: true),
                ),
              if (sync.lastError.value != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ErrorBanner(
                    message: sync.lastError.value!,
                    icon: Icons.sync_problem_rounded,
                  ),
                ),
              SoftCard(
                child: Column(
                  children: [
                    _row(
                      Icons.sync_rounded,
                      'sync_pending'.tr,
                      pending == 0 ? 'sync_all_done'.tr : '$pending',
                      pending == 0 ? AppColors.success : AppColors.warning,
                    ),
                    const Divider(height: 22),
                    _row(
                      Icons.schedule_rounded,
                      'sync_last'.tr,
                      sync.lastSyncAt.value == null
                          ? 'sync_never'.tr
                          : DateFmt.dateTime(sync.lastSyncAt.value!),
                      AppColors.text,
                    ),
                    const Divider(height: 22),
                    _row(
                      Icons.auto_awesome_rounded,
                      'quota_ai'.tr,
                      quota == null
                          ? (_meError ?? '...')
                          : 'quota_value'.trParams({
                              'args1':
                                  '${(quota['limit'] as num) - (quota['used'] as num)}',
                              'args2': '${quota['limit']}',
                            }),
                      AppColors.text,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('server_title'.tr,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('server_hint'.tr,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12.5)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _urlCtl,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      decoration: const InputDecoration(
                          hintText: 'http://192.168.1.10:3000'),
                    ),
                    const SizedBox(height: 8),
                    SecondaryButton(
                      label: 'server_check'.tr,
                      icon: Icons.wifi_tethering_rounded,
                      onPressed: _checking ? null : _saveAndCheck,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'sync_now'.tr,
                icon: Icons.sync_rounded,
                loading: sync.syncing.value,
                onPressed: () async {
                  await sync.sync(force: true);
                  _loadMe();
                },
              ),
              const SizedBox(height: 10),
              SecondaryButton(
                label: 'restore'.tr,
                icon: Icons.cloud_download_outlined,
                onPressed: _restoring ? null : _restore,
              ),
              const SizedBox(height: 16),
              Text(
                'backup_note'.tr,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _row(IconData i, String l, String v, Color c) => Row(
        children: [
          Icon(i, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(l)),
          Flexible(
            child: Text(
              v,
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.w800, color: c),
            ),
          ),
        ],
      );
}

/// Giới thiệu ứng dụng + quyền riêng tư.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) => GradientScaffold(
        appBar: AppHeader(title: 'set_about'.tr),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            children: [
              Center(child: Image.asset(AppAssets.logo, width: 96, height: 96)),
              const SizedBox(height: 10),
              const Center(
                child: Text(
                  'GiftFlow AI',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
              ),
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (_, snap) => Center(
                  child: Text(
                    snap.hasData
                        ? 'v${snap.data!.version}+${snap.data!.buildNumber}'
                        : '',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SoftCard(child: Text('about_desc'.tr)),
              const SizedBox(height: 12),
              SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'privacy_title'.tr,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'privacy_body'.tr,
                      style: const TextStyle(
                          color: AppColors.textSecondary, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'API: ${ApiClient.baseUrl}',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      );
}

class _DocScreen extends StatelessWidget {
  const _DocScreen({required this.titleKey, required this.sections});
  final String titleKey;
  final List<(String, String)> sections;

  @override
  Widget build(BuildContext context) => GradientScaffold(
    appBar: AppHeader(title: titleKey.tr),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          for (final s in sections) ...[
            SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.$1.tr,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s.$2.tr,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    ),
  );
}

/// Quyền riêng tư.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) => const _DocScreen(
    titleKey: 'privacy_title',
    sections: [
      ('privacy_s1_t', 'privacy_s1_b'),
      ('privacy_s2_t', 'privacy_s2_b'),
      ('privacy_s3_t', 'privacy_s3_b'),
      ('privacy_s4_t', 'privacy_s4_b'),
    ],
  );
}

/// Điều khoản sử dụng.
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) => const _DocScreen(
    titleKey: 'terms_title',
    sections: [
      ('terms_s1_t', 'terms_s1_b'),
      ('terms_s2_t', 'terms_s2_b'),
      ('terms_s3_t', 'terms_s3_b'),
    ],
  );
}
