import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controller/event_controller.dart';
import '../../controller/gift_controller.dart';
import '../../controller/settings_controller.dart';
import '../../models/ui_models/gift_status.dart';
import '../../services/application/sync_service.dart';
import '../../utils/money.dart';
import '../../utils/toast_utils.dart';
import '../../values/app_assets.dart';
import '../../values/app_colors.dart';
import '../../values/route_name.dart';
import '../common_components/components.dart';
import '../screen_gifts/quick_entry_sheet.dart';
import '../screen_shell/shell_screen.dart';

/// S04 - Home: event đang chọn, tổng tiền, 2 KPI, lối tắt.
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final events = Get.find<EventController>();
    final gifts = Get.find<GiftController>();
    final settings = Get.find<SettingsController>();
    final sync = Get.find<SyncService>();
    final shell = Get.find<ShellController>();

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async {
          await gifts.reload();
          await sync.sync();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 130),
          children: [
            // Header
            Row(
              children: [
                Image.asset(AppAssets.logo, width: 40, height: 40),
                const SizedBox(width: 10),
                const Text(
                  'GiftFlow',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'AI',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
                const Spacer(),
                Obx(() {
                  final pending = sync.pendingCount.value;
                  return IconButton(
                    tooltip: 'sync_status'.tr,
                    onPressed: () => Get.toNamed(RouteName.backup),
                    icon: Badge(
                      isLabelVisible: pending > 0,
                      label: Text('$pending'),
                      child: Icon(
                        sync.online.value
                            ? Icons.cloud_done_outlined
                            : Icons.cloud_off_rounded,
                        color: sync.online.value
                            ? AppColors.text
                            : AppColors.warning,
                      ),
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 10),
            Obx(() {
              final name = settings.displayName.value;
              return Text(
                name.isEmpty
                    ? 'home_hello_anon'.tr
                    : 'home_hello'.trParams({'args1': name}),
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              );
            }),
            const SizedBox(height: 14),
            Obx(() {
              if (!sync.online.value) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ErrorBanner(
                      message: sync.serverUnreachable.value
                          ? 'server_unreachable'.tr
                          : 'offline_badge'.tr,
                      warning: true),
                );
              }
              return const SizedBox.shrink();
            }),
            Obx(() {
              if (!events.loaded.value) {
                return const Column(
                  children: [
                    LoadingSkeleton(height: 190, radius: 24),
                    SizedBox(height: 12),
                    LoadingSkeleton(height: 80),
                  ],
                );
              }
              final ev = events.active.value;
              if (ev == null) {
                return SizedBox(
                  height: 380,
                  child: EmptyState(
                    icon: Icons.celebration_rounded,
                    title: 'home_no_event_title'.tr,
                    message: 'home_no_event_msg'.tr,
                    actionLabel: 'event_create'.tr,
                    onAction: () => Get.toNamed(
                      RouteName.eventEdit,
                      arguments: {'first': true},
                    ),
                  ),
                );
              }
              final s = gifts.stats.value;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  EventCard(
                    event: ev,
                    totalVnd: null,
                    selected: true,
                    onTap: () => shell.go(1),
                  ),
                  const SizedBox(height: 12),
                  SoftCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'total_received'.tr,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            Money.format(s.totalVnd),
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        if (s.pendingCount > 0) ...[
                          const SizedBox(height: 10),
                          InkWell(
                            onTap: () {
                              gifts.statusFilter.value =
                                  GiftStatus.pendingReview;
                              shell.go(2);
                            },
                            child: StatusPill(
                              label: 'home_pending'.trParams({
                                'args1': '${s.pendingCount}',
                              }),
                              color: AppColors.warning,
                              bg: AppColors.warningBg,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          icon: Icons.mail_outline_rounded,
                          value: '${s.envelopes}',
                          label: 'envelopes'.tr,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          icon: Icons.groups_2_outlined,
                          value: '${s.guests}',
                          label: 'guests'.tr,
                        ),
                      ),
                    ],
                  ),
                  if (s.envelopes == 0 && s.pendingCount == 0) ...[
                    const SizedBox(height: 14),
                    SoftCard(
                      child: Row(
                        children: [
                          const Icon(Icons.mic_rounded,
                              color: AppColors.primary),
                          const SizedBox(width: 12),
                          Expanded(child: Text('home_empty_cta'.tr)),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _Shortcut(
                        icon: Icons.bolt_rounded,
                        label: 'shortcut_quick'.tr,
                        onTap: () {
                          if (ev.isClosed) {
                            Toast.show('event_closed_no_record'.tr);
                          } else {
                            showQuickEntry();
                          }
                        },
                      ),
                      _Shortcut(
                        icon: Icons.format_list_bulleted_rounded,
                        label: 'shortcut_list'.tr,
                        onTap: () => shell.go(2),
                      ),
                      _Shortcut(
                        icon: Icons.bar_chart_rounded,
                        label: 'shortcut_stats'.tr,
                        onTap: () => Get.toNamed(RouteName.statistics),
                      ),
                      _Shortcut(
                        icon: Icons.table_view_rounded,
                        label: 'shortcut_excel'.tr,
                        onTap: () => Get.toNamed(RouteName.export),
                      ),
                    ],
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SoftCard(
            onTap: onTap,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            child: Column(
              children: [
                Icon(icon, color: AppColors.primary, size: 28),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      );
}
