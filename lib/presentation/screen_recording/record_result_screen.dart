import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controller/recording_controller.dart';
import '../../models/data_models/gift_record.dart';
import '../../models/ui_models/gift_status.dart';
import '../../utils/money.dart';
import '../../values/app_colors.dart';
import '../../values/route_name.dart';
import '../common_components/components.dart';
import '../common_components/review_sheet.dart';
import '../screen_shell/shell_screen.dart';

/// S06 - Kết quả phiên ghi: số bản ghi đã ghi / chờ xác nhận / lỗi.
class RecordResultScreen extends StatelessWidget {
  const RecordResultScreen({super.key});

  void _review(RecordingController c, GiftRecord g) {
    if (g.status == GiftStatus.confirmed || g.status == GiftStatus.processing) {
      Get.toNamed(RouteName.giftEdit, arguments: {'id': g.id});
      return;
    }
    showReviewSheet(
      g,
      onConfirm: (n, a, r) => c.confirmItem(g, name: n, amount: a, relationship: r),
      onDelete: () => c.undoItem(g),
      onRetry: c.canRetry(g) ? () => c.retry(g) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.find<RecordingController>();
    return GradientScaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: 'close'.tr,
                onPressed: () => Get.offAllNamed(RouteName.shell),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            Expanded(
              child: Obx(() {
                final ok = c.confirmedCount;
                final pend = c.pendingCount;
                final fail = c.failedCount;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  children: [
                    Center(
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          color: pend + fail > 0
                              ? AppColors.warning
                              : AppColors.success,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          pend + fail > 0
                              ? Icons.priority_high_rounded
                              : Icons.check_rounded,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: Text(
                        'result_title'.tr,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SoftCard(
                      child: Column(
                        children: [
                          _line(
                            Icons.check_circle_rounded,
                            'result_confirmed'.tr,
                            '$ok · ${Money.format(c.confirmedTotal)}',
                            AppColors.success,
                          ),
                          if (pend > 0)
                            _line(
                              Icons.hourglass_top_rounded,
                              'result_pending'.tr,
                              '$pend',
                              AppColors.warning,
                            ),
                          if (fail > 0)
                            _line(
                              Icons.error_outline_rounded,
                              'result_failed'.tr,
                              '$fail',
                              AppColors.danger,
                            ),
                        ],
                      ),
                    ),
                    if (pend > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: ErrorBanner(
                          message: 'result_pending_note'.tr,
                          warning: true,
                          icon: Icons.info_outline_rounded,
                        ),
                      ),
                    const SizedBox(height: 16),
                    for (final g in c.items) ...[
                      GiftRow(
                        gift: g,
                        showSync: false,
                        onTap: () => _review(c, g),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      label: 'result_continue'.tr,
                      onPressed: () => Get.offNamed(RouteName.recording),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PrimaryButton(
                      label: 'result_view_list'.tr,
                      onPressed: () {
                        Get.offAllNamed(RouteName.shell);
                        Get.find<ShellController>().go(2);
                      },
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

  Widget _line(IconData i, String label, String value, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Icon(i, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        Text(value, style: TextStyle(fontWeight: FontWeight.w800, color: color)),
      ],
    ),
  );
}
