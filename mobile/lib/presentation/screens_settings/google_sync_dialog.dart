import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../services/application/google_auth_service.dart';
import '../../values/app_colors.dart';

String _counts(Map<String, int> c) {
  final parts = <String>[
    if ((c['events'] ?? 0) > 0) '${c['events']} ${'sync_n_events'.tr}',
    if ((c['gifts'] ?? 0) > 0) '${c['gifts']} ${'sync_n_gifts'.tr}',
    if ((c['plan_items'] ?? 0) > 0) '${c['plan_items']} ${'sync_n_plan_items'.tr}',
    if ((c['plan_guests'] ?? 0) > 0) '${c['plan_guests']} ${'sync_n_plan_guests'.tr}',
    if ((c['invitations'] ?? 0) > 0) '${c['invitations']} ${'sync_n_invitations'.tr}',
  ];
  return parts.isEmpty ? '—' : parts.join(' · ');
}

/// Hộp thoại hỏi đồng bộ: tài khoản Google đã có dữ liệu VÀ máy này cũng có dữ liệu.
Future<SyncChoice> showGoogleSyncChoice(GoogleSyncPreview p) async {
  final r = await Get.dialog<SyncChoice>(
    _SyncChoiceDialog(p),
    barrierDismissible: false,
  );
  return r ?? SyncChoice.cancel;
}

class _SyncChoiceDialog extends StatelessWidget {
  const _SyncChoiceDialog(this.p);
  final GoogleSyncPreview p;

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: AppColors.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    title: Row(
      children: [
        const Icon(Icons.cloud_sync_rounded, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'sync_dlg_title'.tr,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
        ),
      ],
    ),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'sync_dlg_intro'.trParams({'args1': p.email ?? 'Google'}),
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 12),
          _block(Icons.cloud_done_outlined, 'sync_dlg_account'.tr, _counts(p.account)),
          const SizedBox(height: 8),
          _block(Icons.smartphone_rounded, 'sync_dlg_local'.tr, _counts(p.local)),
          const SizedBox(height: 14),
          _option(
            icon: Icons.merge_rounded,
            title: 'sync_choice_merge'.tr,
            desc: 'sync_choice_merge_desc'.tr,
            primary: true,
            onTap: () => Get.back(result: SyncChoice.merge),
          ),
          const SizedBox(height: 8),
          _option(
            icon: Icons.cloud_download_outlined,
            title: 'sync_choice_account'.tr,
            desc: 'sync_choice_account_desc'.tr,
            onTap: () => _confirmReplace(),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Get.back(result: SyncChoice.cancel),
        child: Text('sync_choice_cancel'.tr),
      ),
    ],
  );

  Future<void> _confirmReplace() async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('sync_replace_title'.tr),
        content: Text('sync_replace_msg'.tr),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: Text('cancel'.tr)),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text(
              'sync_replace_confirm'.tr,
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (ok == true) Get.back(result: SyncChoice.useAccount);
  }

  Widget _block(IconData i, String title, String counts) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.chip,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(i, size: 20, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
              const SizedBox(height: 2),
              Text(counts, style: const TextStyle(fontSize: 13, height: 1.3)),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _option({
    required IconData icon,
    required String title,
    required String desc,
    required VoidCallback onTap,
    bool primary = false,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: primary ? AppColors.primary.withValues(alpha: 0.12) : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: primary ? AppColors.primary : AppColors.border,
          width: primary ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Tiến trình tải dữ liệu tài khoản về (đăng nhập sau khi cài lại app...).
void showRestoringDialog() {
  Get.dialog<void>(
    PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: AppColors.surface,
        content: Row(
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(width: 18),
            Expanded(child: Text('sync_restoring'.tr)),
          ],
        ),
      ),
    ),
    barrierDismissible: false,
  );
}
