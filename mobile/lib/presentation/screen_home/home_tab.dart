import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../controller/event_controller.dart';
import '../../controller/gift_controller.dart';
import '../../controller/settings_controller.dart';
import '../../services/application/sync_service.dart';
import '../../utils/date_fmt.dart';
import '../../utils/money.dart';
import '../../utils/toast_utils.dart';
import '../../values/app_assets.dart';
import '../../values/app_colors.dart';
import '../../values/route_name.dart';
import '../common_components/components.dart';
import '../common_components/ui_kit.dart';
import '../screen_gifts/quick_entry_sheet.dart';
import '../screen_plan/plan_entry_card.dart';
import '../screen_shell/shell_screen.dart';

/// S04 - Trang chủ: sự kiện đang chọn, tổng tiền, thống kê nhanh, thao tác nhanh.
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  void _openMic() {
    final ev = Get.find<EventController>().active.value;
    if (ev == null) {
      Toast.show('need_event_first'.tr);
      Get.toNamed(RouteName.eventEdit, arguments: {'first': true});
    } else if (ev.isClosed) {
      Toast.show('event_closed_no_record'.tr);
    } else {
      Get.toNamed(RouteName.recording);
    }
  }

  bool _needEvent() {
    final ev = Get.find<EventController>().active.value;
    if (ev == null) {
      Toast.show('need_event_first'.tr);
      Get.toNamed(RouteName.eventEdit, arguments: {'first': true});
      return true;
    }
    if (ev.isClosed) {
      Toast.show('event_closed_no_record'.tr);
      return true;
    }
    return false;
  }

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
            _header(sync, gifts, shell),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Obx(() {
                        final name = settings.displayName.value;
                        return Text(
                          name.isEmpty
                              ? 'home_hello_anon'.tr
                              : 'home_hello'.trParams({'args1': name}),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        );
                      }),
                      const SizedBox(height: 2),
                      Text(
                        'home_tagline'.tr,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const HeaderBadge(main: '🎁', sub: ['✨', '💜', '🎀']),
              ],
            ),
            const SizedBox(height: 10),
            Obx(() {
              if (sync.online.value) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ErrorBanner(
                  message: sync.serverUnreachable.value
                      ? 'server_unreachable'.tr
                      : 'offline_badge'.tr,
                  warning: true,
                ),
              );
            }),
            Obx(() {
              if (!events.loaded.value) {
                return const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final ev = events.active.value;
              if (ev == null) {
                return SoftCard(
                  child: EmptyState(
                    icon: Icons.event_outlined,
                    title: 'home_no_event'.tr,
                    message: 'home_no_event_msg'.tr,
                    actionLabel: 'event_create'.tr,
                    onAction: () => Get.toNamed(
                      RouteName.eventEdit,
                      arguments: {'first': true},
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  _eventCard(ev),
                  const SizedBox(height: 14),
                  _totalCard(gifts),
                  const SizedBox(height: 12),
                  _kpis(gifts),
                  const SizedBox(height: 14),
                  _quickStats(gifts, ev.id),
                  const SizedBox(height: 14),
                  PlanEntryCard(eventId: ev.id),
                ],
              );
            }),
            const SizedBox(height: 14),
            _actions(shell),
            const SizedBox(height: 14),
            _detailBanner(),
          ],
        ),
      ),
    );
  }

  Widget _header(SyncService sync, GiftController gifts, ShellController shell) {
    return Row(
      children: [
        Image.asset(AppAssets.logo, width: 38, height: 38),
        const SizedBox(width: 8),
        const Text(
          'GiftFlow',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 6),
        const AiBadge(),
        const Spacer(),
        // Chuông: số bản ghi đang chờ xác nhận -> mở danh sách.
        Obx(() {
          final n = gifts.stats.value.pendingCount;
          return IconButton(
            tooltip: 'home_pending_tip'.tr,
            onPressed: () => shell.go(2),
            icon: Badge(
              isLabelVisible: n > 0,
              backgroundColor: AppColors.danger,
              label: Text('$n'),
              child: const Icon(Icons.notifications_none_rounded),
            ),
          );
        }),
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
                color: sync.online.value ? AppColors.text : AppColors.warning,
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _eventCard(dynamic ev) {
    final ph = phaseStyle(ev.phaseOn(DateTime.now()));
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: AppTouchableCard(
        onTap: () =>
            Get.toNamed(RouteName.eventDetail, arguments: {'id': ev.id}),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              EventThumb(type: ev.type, size: 62),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            ev.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusPill(
                          label: ph.label,
                          color: ph.color,
                          bg: ph.bg,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          DateFmt.display(ev.eventDate),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _totalCard(GiftController gifts) => Obx(() {
    final s = gifts.stats.value;
    final today = gifts.todayVnd.value;
    final pct = s.totalVnd > 0 ? today / s.totalVnd * 100 : 0.0;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 14, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFA06BF3), Color(0xFF7B3FE4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'home_total'.tr,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    Money.format(s.totalVnd),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (today > 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.arrow_upward_rounded,
                          color: Color(0xFF9CFFC8),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '+${Money.format(today)} (${pct.toStringAsFixed(1).replaceAll('.', ',')}%)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 6),
                  Text(
                    'home_today_none'.tr,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const Text('💌', style: TextStyle(fontSize: 54)),
        ],
      ),
    );
  });

  Widget _kpis(GiftController gifts) => Obx(() {
    final s = gifts.stats.value;
    final avg = s.guests > 0 ? (s.totalVnd / s.guests).round() : 0;
    return Row(
      children: [
        Expanded(
          flex: 9,
          child: StatBox(
            icon: Icons.mail_outline_rounded,
            value: '${s.envelopes}',
            label: 'kpi_envelopes'.tr,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 9,
          child: StatBox(
            icon: Icons.groups_rounded,
            value: '${s.guests}',
            label: 'kpi_guests'.tr,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 14,
          child: StatBox(
            icon: Icons.savings_outlined,
            iconColor: AppColors.warning,
            value: 'Ø ${Money.format(avg)}',
            label: 'kpi_avg'.tr,
          ),
        ),
      ],
    );
  });

  Widget _quickStats(GiftController gifts, String eventId) => Obx(() {
    final s = gifts.stats.value;
    final rels = s.byRelationship.where((r) => r.count > 0).toList();
    final total = rels.fold<int>(0, (a, b) => a + b.count);
    return SoftCard(
      onTap: () => Get.toNamed(
        RouteName.eventDetail,
        arguments: {'id': eventId, 'tab': 3},
      ),
      child: Column(
        children: [
          SectionTitle(
            title: 'home_quick_stats'.tr,
            icon: Icons.bar_chart_rounded,
          ),
          const SizedBox(height: 12),
          if (total == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'stats_empty'.tr,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            )
          else
            Row(
              children: [
                DonutChart(
                  values: rels.map((r) => r.count.toDouble()).toList(),
                  centerTop: '${s.guests}',
                  centerBottom: 'kpi_guests'.tr,
                  size: 118,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      for (var i = 0; i < rels.length && i < 5; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: AppColors
                                      .chart[i % AppColors.chart.length],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  rels[i].label.isEmpty
                                      ? 'rel_none'.tr
                                      : rels[i].label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              Text(
                                '${rels[i].count}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              SizedBox(
                                width: 44,
                                child: Text(
                                  '${(rels[i].count / total * 100).round()}%',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  });

  Widget _actions(ShellController shell) {
    Widget tile({
      required IconData icon,
      required String label,
      required VoidCallback onTap,
      Color tint = AppColors.primary,
      Color bg = AppColors.chip,
      bool ai = false,
    }) => Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
          ),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: tint),
                  ),
                  if (ai) const Positioned(right: -8, top: -6, child: AiBadge()),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 3,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return SoftCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title: 'home_actions'.tr, icon: Icons.bolt_rounded),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              tile(
                icon: Icons.mic_rounded,
                label: 'act_voice'.tr,
                ai: true,
                bg: const Color(0xFFFFE7F1),
                tint: const Color(0xFFE0457B),
                onTap: _openMic,
              ),
              const SizedBox(width: 8),
              tile(
                icon: Icons.playlist_add_rounded,
                label: 'act_manual'.tr,
                onTap: () {
                  if (_needEvent()) return;
                  Get.toNamed(RouteName.giftEdit);
                },
              ),
              const SizedBox(width: 8),
              tile(
                icon: Icons.document_scanner_outlined,
                label: 'act_scan'.tr,
                onTap: () {
                  if (_needEvent()) return;
                  showQuickEntry(scanSource: ImageSource.gallery);
                },
              ),
              const SizedBox(width: 8),
              tile(
                icon: Icons.photo_camera_outlined,
                label: 'act_camera'.tr,
                ai: true,
                bg: const Color(0xFFDDEBFF),
                tint: const Color(0xFF3A6FE0),
                onTap: () {
                  if (_needEvent()) return;
                  showQuickEntry(scanSource: ImageSource.camera);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailBanner() => Obx(() {
    final ev = Get.find<EventController>().active.value;
    return GestureDetector(
      onTap: () => ev == null
          ? Get.toNamed(RouteName.eventEdit, arguments: {'first': true})
          : Get.toNamed(
              RouteName.eventDetail,
              arguments: {'id': ev.id, 'tab': 3},
            ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEBDDFF), Color(0xFFDCCBFB)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            const Text('📊', style: TextStyle(fontSize: 38)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'home_detail_stats'.tr,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    'home_detail_stats_sub'.tr,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  });
}

/// Vùng chạm có hiệu ứng cho thẻ tự vẽ viền.
class AppTouchableCard extends StatelessWidget {
  const AppTouchableCard({super.key, required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(22),
    child: InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: child,
    ),
  );
}
