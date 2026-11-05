import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controller/event_controller.dart';
import '../../models/data_models/gift_event.dart';
import '../../utils/toast_utils.dart';
import '../../values/app_colors.dart';
import '../../values/route_name.dart';
import '../common_components/components.dart';
import '../common_components/dialogs.dart';

/// S11 - Danh sách sự kiện: chọn active, tạo mới, sửa / đóng / xoá.
class EventsTab extends StatelessWidget {
  const EventsTab({super.key});

  Future<void> _menu(EventController c, GiftEvent e) async {
    final choice = await Get.bottomSheet<String>(
      SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            _tile(Icons.check_circle_outline_rounded, 'event_select'.tr, 'select'),
            _tile(Icons.edit_outlined, 'edit'.tr, 'edit'),
            _tile(
              e.isClosed ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
              e.isClosed ? 'event_reopen'.tr : 'event_close'.tr,
              'toggle',
            ),
            _tile(Icons.delete_outline_rounded, 'delete'.tr, 'delete', danger: true),
            const SizedBox(height: 8),
          ],
        ),
      ),
      backgroundColor: AppColors.surface,
    );
    switch (choice) {
      case 'select':
        if (e.isClosed) {
          Toast.show('event_closed_no_record'.tr);
        }
        await c.setActive(e.id);
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
        if (ok) await c.delete(e);
    }
  }

  Widget _tile(IconData i, String t, String v, {bool danger = false}) =>
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

  @override
  Widget build(BuildContext context) {
    final c = Get.find<EventController>();
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              'events_title'.tr,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            child: Obx(() {
              if (!c.loaded.value) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: LoadingSkeleton(height: 110, radius: 20),
                );
              }
              final list = c.events.toList();
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 130),
                children: [
                  if (list.isEmpty)
                    SizedBox(
                      height: 360,
                      child: EmptyState(
                        icon: Icons.event_note_rounded,
                        title: 'events_empty_title'.tr,
                        message: 'events_empty_msg'.tr,
                      ),
                    ),
                  for (final e in list) ...[
                    EventCard(
                      event: e,
                      totalVnd: c.totals[e.id] ?? 0,
                      selected: c.active.value?.id == e.id,
                      onTap: () => _menu(c, e).then((_) {}),
                      onMore: () => _menu(c, e),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 4),
                  SecondaryButton(
                    label: 'event_create'.tr,
                    icon: Icons.add_rounded,
                    onPressed: () => Get.toNamed(RouteName.eventEdit),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}
