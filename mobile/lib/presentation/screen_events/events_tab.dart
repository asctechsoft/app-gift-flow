import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controller/event_controller.dart';
import '../../models/data_models/gift_event.dart';
import '../../utils/date_fmt.dart';
import '../../utils/money.dart';
import '../../values/app_colors.dart';
import '../../values/route_name.dart';
import '../common_components/components.dart';
import '../common_components/ui_kit.dart';
import 'event_actions.dart';

/// S11 - Danh sách sự kiện: tổng quan, lọc theo trạng thái, thẻ sự kiện, tạo mới.
class EventsTab extends StatefulWidget {
  const EventsTab({super.key});

  @override
  State<EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<EventsTab> {
  /// null = tất cả; còn lại lọc theo trạng thái diễn ra.
  EventPhase? _phase;

  @override
  Widget build(BuildContext context) {
    final c = Get.find<EventController>();
    return SafeArea(
      bottom: false,
      child: Obx(() {
        if (!c.loaded.value) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: LoadingSkeleton(height: 110, radius: 20),
          );
        }
        final now = DateTime.now();
        final all = c.events.toList();
        final stats = c.statsById;
        int count(EventPhase? p) => p == null
            ? all.length
            : all.where((e) => e.phaseOn(now) == p).length;
        final list = _phase == null
            ? all
            : all.where((e) => e.phaseOn(now) == _phase).toList();
        final totalVnd = all.fold<int>(0, (a, e) => a + (c.totals[e.id] ?? 0));
        final guests = all.fold<int>(0, (a, e) => a + (stats[e.id]?.guests ?? 0));

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 130),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'events_title'.tr,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'events_subtitle'.tr,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const HeaderBadge(main: '📅', sub: ['💜', '✨', '🎈']),
              ],
            ),
            const SizedBox(height: 12),
            _overview(all.length, totalVnd, guests),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _chip('events_all'.tr, count(null), null),
                  _chip('phase_ongoing'.tr, count(EventPhase.ongoing),
                      EventPhase.ongoing),
                  _chip('phase_upcoming'.tr, count(EventPhase.upcoming),
                      EventPhase.upcoming),
                  _chip('phase_ended'.tr, count(EventPhase.ended),
                      EventPhase.ended),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (list.isEmpty)
              SizedBox(
                height: 240,
                child: EmptyState(
                  icon: Icons.event_note_rounded,
                  title: 'events_empty_title'.tr,
                  message: 'events_empty_msg'.tr,
                ),
              ),
            for (final e in list) ...[
              _eventCard(c, e, now),
              const SizedBox(height: 12),
            ],
            _createButton(),
            const SizedBox(height: 14),
            _tip(),
          ],
        );
      }),
    );
  }

  Widget _overview(int events, int totalVnd, int guests) => Container(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFA06BF3), Color(0xFF7B3FE4)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.25),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'events_overview'.tr,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _ov(Icons.event_note_rounded, '$events', 'events_count'.tr),
            _ov(Icons.savings_outlined, Money.format(totalVnd),
                'home_total'.tr, flex: 3),
            _ov(Icons.groups_rounded, '$guests', 'kpi_guests'.tr),
          ],
        ),
      ],
    ),
  );

  Widget _ov(IconData i, String v, String l, {int flex = 2}) => Expanded(
    flex: flex,
    child: Row(
      children: [
        Icon(i, color: Colors.white70, size: 22),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  v,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
              Text(
                l,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 11.5),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _chip(String label, int n, EventPhase? p) {
    final sel = _phase == p;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _phase = p),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: sel ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: sel ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Text(
            '$label ($n)',
            style: TextStyle(
              color: sel ? Colors.white : AppColors.text,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _eventCard(EventController c, GiftEvent e, DateTime now) {
    final st = c.statsById[e.id];
    final ph = phaseStyle(e.phaseOn(now));
    final selected = c.active.value?.id == e.id;
    return GestureDetector(
      onTap: () => Get.toNamed(RouteName.eventDetail, arguments: {'id': e.id}),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border.withValues(alpha: 0.7),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            EventThumb(type: e.type, size: 74),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        e.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      StatusPill(label: ph.label, color: ph.color, bg: ph.bg),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 13,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        DateFmt.display(e.eventDate),
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    Money.format(c.totals[e.id] ?? 0),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 19,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.mail_outline_rounded,
                          size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        '${st?.envelopes ?? 0} ${'kpi_envelopes'.tr}',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.groups_outlined,
                          size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        '${st?.guests ?? 0} ${'kpi_guests'.tr}',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'more'.tr,
              icon: const Icon(Icons.more_vert_rounded),
              onPressed: () => showEventMenu(c, e),
            ),
          ],
        ),
      ),
    );
  }

  Widget _createButton() => GestureDetector(
    onTap: () => Get.toNamed(RouteName.eventEdit),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.55),
          width: 1.4,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.add_rounded, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            'event_create'.tr,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _tip() => GestureDetector(
    onTap: () => Get.toNamed(RouteName.eventEdit),
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
          const Text('🎁', style: TextStyle(fontSize: 38)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'events_tip_title'.tr,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                Text(
                  'events_tip_msg'.tr,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 34,
            height: 34,
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
}
