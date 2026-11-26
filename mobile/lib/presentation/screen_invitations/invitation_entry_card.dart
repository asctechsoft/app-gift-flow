import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controller/invitation_controller.dart';
import '../../utils/money.dart';
import '../../values/app_colors.dart';
import '../../values/route_name.dart';
import '../common_components/components.dart';

/// Thẻ lối vào "Lịch đi mừng" trên Trang chủ: lời mời gần nhất + tổng dự chi.
class InvitationEntryCard extends StatelessWidget {
  const InvitationEntryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<InvitationController>();
    return Obx(() {
      final s = c.stats.value;
      final n = s.next;
      final days = n?.daysUntil(DateTime.now());
      return SoftCard(
        onTap: () => Get.toNamed(RouteName.invitations),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.chip,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text('🎁', style: TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'inv_title'.tr,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    n == null
                        ? 'inv_entry_empty'.tr
                        : '${n.personName} · ${days == 0 ? 'inv_today'.tr : 'inv_days_left'.trParams({'args1': '${days ?? 0}'})}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  if (s.upcomingPlannedVnd > 0)
                    Text(
                      '${'inv_kpi_planned'.tr}: ${Money.format(s.upcomingPlannedVnd)}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
          ],
        ),
      );
    });
  }
}
