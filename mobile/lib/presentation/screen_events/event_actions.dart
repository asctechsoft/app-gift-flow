import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controller/event_controller.dart';
import '../../models/data_models/gift_event.dart';
import '../../utils/toast_utils.dart';
import '../../values/app_colors.dart';
import '../../values/route_name.dart';
import '../common_components/dialogs.dart';

/// Menu hành động của một sự kiện (dùng ở danh sách và màn chi tiết).
/// Trả về true nếu sự kiện đã bị xoá (màn chi tiết cần đóng lại).
Future<bool> showEventMenu(
  EventController c,
  GiftEvent e, {
  bool withDetail = true,
}) async {
  Widget tile(IconData i, String t, String v, {bool danger = false}) =>
      ListTile(
        leading: Icon(i, color: danger ? AppColors.danger : AppColors.primary),
        title: Text(
          t,
          style: TextStyle(
            color: danger ? AppColors.danger : AppColors.text,
            fontWeight: FontWeight.w600,
          ),
        ),
        onTap: () => Get.back(result: v),
      );

  final choice = await Get.bottomSheet<String>(
    SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          if (withDetail)
            tile(Icons.open_in_new_rounded, 'event_open_detail'.tr, 'detail'),
          tile(Icons.check_circle_outline_rounded, 'event_select'.tr, 'select'),
          tile(Icons.edit_outlined, 'edit'.tr, 'edit'),
          tile(
            e.isClosed ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
            e.isClosed ? 'event_reopen'.tr : 'event_close'.tr,
            'toggle',
          ),
          tile(Icons.delete_outline_rounded, 'delete'.tr, 'delete', danger: true),
          const SizedBox(height: 8),
        ],
      ),
    ),
    backgroundColor: AppColors.surface,
  );
  switch (choice) {
    case 'detail':
      Get.toNamed(RouteName.eventDetail, arguments: {'id': e.id});
    case 'select':
      if (e.isClosed) Toast.show('event_closed_no_record'.tr);
      await c.setActive(e.id);
      Toast.show('event_selected'.trParams({'args1': e.name}));
    case 'edit':
      Get.toNamed(RouteName.eventEdit, arguments: {'id': e.id});
    case 'toggle':
      await c.setClosed(e, !e.isClosed);
    case 'delete':
      final ok = await confirmDialog(
        title: 'event_delete_title'.tr,
        message: 'event_delete_msg'.trParams({'args1': e.name}),
        confirmLabel: 'delete'.tr,
        danger: true,
      );
      if (ok) {
        await c.delete(e);
        return true;
      }
  }
  return false;
}
