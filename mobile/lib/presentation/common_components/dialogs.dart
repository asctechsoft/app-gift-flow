import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../values/app_colors.dart';
import 'components.dart';

/// Hộp thoại xác nhận chung (xoá, đóng sự kiện...). Trả true nếu đồng ý.
Future<bool> confirmDialog({
  required String title,
  required String message,
  required String confirmLabel,
  bool danger = false,
}) async {
  final r = await Get.dialog<bool>(
    Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'cancel'.tr,
                    onPressed: () => Get.back(result: false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PrimaryButton(
                    label: confirmLabel,
                    color: danger ? AppColors.danger : null,
                    onPressed: () => Get.back(result: true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return r ?? false;
}

/// Snackbar có nút hoàn tác (xoá mềm -> undo tạm thời).
void showUndoSnack(String message, VoidCallback onUndo) {
  final ctx = Get.context;
  if (ctx == null) return;
  final m = ScaffoldMessenger.of(ctx);
  m.hideCurrentSnackBar();
  m.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 6),
      action: SnackBarAction(
        label: 'undo'.tr,
        textColor: AppColors.accent,
        onPressed: onUndo,
      ),
    ),
  );
}
