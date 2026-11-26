import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controller/plan_controller.dart';
import '../../utils/money.dart';
import '../../values/app_colors.dart';
import '../../values/route_name.dart';
import '../common_components/components.dart';

/// Thẻ lối vào "Kế hoạch" (Trang chủ + Chi tiết sự kiện): tóm tắt ngân sách và khách dự kiến.
class PlanEntryCard extends StatefulWidget {
  const PlanEntryCard({super.key, required this.eventId});
  final String eventId;

  @override
  State<PlanEntryCard> createState() => _PlanEntryCardState();
}

class _PlanEntryCardState extends State<PlanEntryCard> {
  final PlanController c = Get.find<PlanController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => c.open(widget.eventId));
  }

  @override
  void didUpdateWidget(covariant PlanEntryCard old) {
    super.didUpdateWidget(old);
    if (old.eventId != widget.eventId) c.open(widget.eventId);
  }

  @override
  Widget build(BuildContext context) => Obx(() {
    final same = c.eventId.value == widget.eventId;
    final s = c.summary.value;
    final empty = !same || (s.plannedVnd == 0 && s.guestCount == 0 && c.items.isEmpty);
    final ratio = (same ? s.budgetUsedRatio : null);
    return SoftCard(
      onTap: () => Get.toNamed(RouteName.plan, arguments: {'id': widget.eventId}),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.chip,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text('📝', style: TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'plan_title'.tr,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      empty
                          ? 'plan_entry_empty'.tr
                          : '${'plan_planned_total'.tr}: ${Money.format(s.plannedVnd)}\n'
                                '${'plan_tab_guests'.tr}: ${s.guestCount} (${s.headcountExpected} ${'plan_people'.tr})',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ],
          ),
          if (ratio != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: ratio.clamp(0.0, 1.0).toDouble(),
                      minHeight: 8,
                      backgroundColor: AppColors.chip,
                      valueColor: AlwaysStoppedAnimation(
                        s.overBudget ? AppColors.danger : AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${(ratio * 100).round()}%',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: s.overBudget ? AppColors.danger : AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  });
}
