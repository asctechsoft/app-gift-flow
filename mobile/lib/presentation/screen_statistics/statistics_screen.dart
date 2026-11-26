import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controller/event_controller.dart';
import '../../controller/gift_controller.dart';
import '../../models/ui_models/gift_status.dart';
import '../../repository/gift_repository.dart';
import '../../utils/money.dart';
import '../../values/app_colors.dart';
import '../common_components/components.dart';

/// S09 - Thống kê: tổng confirmed, số khách, số phong bì, phân loại quan hệ.
/// Số liệu lấy từ SQLite (SUM confirmed, chưa xoá) nên khớp danh sách/Excel.
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final GiftController c = Get.find<GiftController>();
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    c.reload();
  }

  String _label(RelationshipStat r) =>
      r.label.isEmpty ? 'rel_none'.tr : r.label;

  @override
  Widget build(BuildContext context) => GradientScaffold(
        appBar: AppHeader(title: 'stats_title'.tr),
        body: SafeArea(
          child: Obx(() {
            final ev = Get.find<EventController>().active.value;
            final s = c.stats.value;
            if (ev == null) {
              return EmptyState(
                icon: Icons.event_busy_rounded,
                title: 'home_no_event_title'.tr,
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                Text(
                  ev.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                _segmented(),
                const SizedBox(height: 14),
                SoftCard(
                  padding:
                      const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  child: Column(
                    children: [
                      Text(
                        'total_received'.tr,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
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
                if (s.envelopes > 0) ...[
                  const SizedBox(height: 12),
                  SoftCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'stats_by_side'.tr,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        for (final side in GiftSide.all)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Icon(
                                  side == GiftSide.parents
                                      ? Icons.family_restroom_rounded
                                      : Icons.emoji_people_rounded,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: Text(GiftSide.labelKey(side).tr)),
                                Text(
                                  '${s.bySide.where((e) => e.side == side).fold<int>(0, (a, b) => a + b.count)} · ${Money.format(s.bySide.where((e) => e.side == side).fold<int>(0, (a, b) => a + b.totalVnd))}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                if (s.pendingCount > 0) ...[
                  const SizedBox(height: 12),
                  ErrorBanner(
                    warning: true,
                    icon: Icons.hourglass_top_rounded,
                    message: 'stats_pending_note'.trParams({
                      'args1': '${s.pendingCount}',
                      'args2': Money.format(s.pendingVnd),
                    }),
                  ),
                ],
                const SizedBox(height: 16),
                if (s.envelopes == 0)
                  SizedBox(
                    height: 220,
                    child: EmptyState(
                      icon: Icons.bar_chart_rounded,
                      title: 'stats_empty'.tr,
                    ),
                  )
                else if (_tab == 0)
                  _overview(s)
                else
                  _byRelationship(s),
                if (s.envelopes > 0) ...[
                  const SizedBox(height: 16),
                  TopGiversCard(
                    entries: [
                      for (final g in s.topGuests)
                        (name: g.name, amount: g.totalVnd)
                    ],
                  ),
                ],
              ],
            );
          }),
        ),
      );

  Widget _segmented() => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.chip,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            for (final t in [
              (0, 'stats_tab_overview'.tr),
              (1, 'stats_tab_rel'.tr)
            ])
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _tab = t.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color:
                          _tab == t.$1 ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      t.$2,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _tab == t.$1 ? Colors.white : AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );

  Widget _overview(EventStats s) {
    final total = s.byRelationship.fold<int>(0, (a, b) => a + b.count);
    return SoftCard(
      child: Row(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: CustomPaint(
              painter: _DonutPainter(
                s.byRelationship.map((e) => e.count.toDouble()).toList(),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: [
                for (var i = 0; i < s.byRelationship.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.chart[i % AppColors.chart.length],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _label(s.byRelationship[i]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        Text(
                          '${s.byRelationship[i].count}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 38,
                          child: Text(
                            '${(s.byRelationship[i].count * 100 / total).round()}%',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
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
    );
  }

  Widget _byRelationship(EventStats s) {
    final max =
        s.byRelationship.fold<int>(0, (a, b) => math.max(a, b.totalVnd));
    return Column(
      children: [
        for (var i = 0; i < s.byRelationship.length; i++) ...[
          SoftCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _label(s.byRelationship[i]),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      Money.format(s.byRelationship[i].totalVnd),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: max == 0 ? 0 : s.byRelationship[i].totalVnd / max,
                    minHeight: 8,
                    backgroundColor: AppColors.chip,
                    color: AppColors.chart[i % AppColors.chart.length],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'rel_count'
                      .trParams({'args1': '${s.byRelationship[i].count}'}),
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.values);
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (a, b) => a + b);
    final rect = Offset.zero & size;
    const stroke = 22.0;
    final r = rect.deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = AppColors.chip;
    canvas.drawArc(r, 0, math.pi * 2, false, base);
    if (total <= 0) return;
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * math.pi * 2;
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt
        ..color = AppColors.chart[i % AppColors.chart.length];
      canvas.drawArc(r, start, math.max(0, sweep - 0.03), false, p);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.values != values;
}
