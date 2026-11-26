import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controller/event_controller.dart';
import '../../controller/gift_controller.dart';
import '../../models/data_models/gift_record.dart';
import '../../models/ui_models/gift_status.dart';
import '../../services/application/sync_service.dart';
import '../../utils/money.dart';
import '../../utils/toast_utils.dart';
import '../../values/app_colors.dart';
import '../../values/route_name.dart';
import '../common_components/components.dart';
import '../common_components/review_sheet.dart';
import 'quick_entry_sheet.dart';

/// S07 - Danh sách ghi nhận: tìm kiếm, lọc, tổng, FAB thêm tay.
class GiftsTab extends StatefulWidget {
  const GiftsTab({super.key});

  @override
  State<GiftsTab> createState() => _GiftsTabState();
}

class _GiftsTabState extends State<GiftsTab> {
  final TextEditingController _search = TextEditingController();
  final GiftController c = Get.find<GiftController>();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _guardEvent(VoidCallback go) {
    final ev = Get.find<EventController>().active.value;
    if (ev == null) {
      Toast.show('need_event_first'.tr);
    } else if (ev.isClosed) {
      Toast.show('event_closed_no_record'.tr);
    } else {
      go();
    }
  }

  void _open(GiftRecord g) {
    if (g.status == GiftStatus.pendingReview || g.status == GiftStatus.failed) {
      showReviewSheet(
        g,
        onConfirm: (n, a, r) =>
            c.confirm(g, name: n, amount: a, relationship: r),
        onDelete: () async {
          await c.delete(g.id);
          Toast.show('deleted'.tr);
        },
      );
    } else {
      Get.toNamed(RouteName.giftEdit, arguments: {'id': g.id});
    }
  }

  Future<void> _filterSheet() async {
    final r = await Get.bottomSheet<(GiftStatus?,)>(
      SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Text(
                'filter_status'.tr,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
            for (final o in <(String, GiftStatus?)>[
              ('filter_all'.tr, null),
              ('status_confirmed'.tr, GiftStatus.confirmed),
              ('status_pending'.tr, GiftStatus.pendingReview),
              ('status_failed'.tr, GiftStatus.failed),
            ])
              ListTile(
                title: Text(o.$1),
                trailing: c.statusFilter.value == o.$2
                    ? const Icon(Icons.check_rounded, color: AppColors.primary)
                    : null,
                onTap: () => Get.back(result: (o.$2,)),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
      backgroundColor: AppColors.surface,
    );
    if (r != null) c.statusFilter.value = r.$1;
  }

  @override
  Widget build(BuildContext context) {
    final sync = Get.find<SyncService>();
    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'list_title'.tr,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Obx(() {
                      if (sync.online.value) return const SizedBox.shrink();
                      return const Icon(
                        Icons.cloud_off_rounded,
                        color: AppColors.warning,
                      );
                    }),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _search,
                        onChanged: (v) => c.query.value = v,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'search_hint'.tr,
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: ValueListenableBuilder(
                            valueListenable: _search,
                            builder: (_, v, _) => v.text.isEmpty
                                ? const SizedBox.shrink()
                                : IconButton(
                                    icon: const Icon(Icons.close_rounded),
                                    onPressed: () {
                                      _search.clear();
                                      c.query.value = '';
                                    },
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Obx(
                      () => Badge(
                        isLabelVisible: c.statusFilter.value != null,
                        smallSize: 10,
                        child: IconButton.filledTonal(
                          tooltip: 'filter'.tr,
                          onPressed: _filterSheet,
                          style: IconButton.styleFrom(
                            minimumSize: const Size(52, 52),
                            backgroundColor: AppColors.chip,
                            foregroundColor: AppColors.primary,
                          ),
                          icon: const Icon(Icons.tune_rounded),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Obx(
                  () => SideSelector(
                    value: c.sideFilter.value,
                    allowAll: true,
                    dense: true,
                    onChanged: (v) => c.sideFilter.value = v,
                  ),
                ),
              ),
              // Chip lọc theo quan hệ
              Obx(() {
                final rels = c.relCounts.toList();
                if (rels.isEmpty) return const SizedBox(height: 8);
                return SizedBox(
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    children: [
                      _chip(
                        '${'filter_all'.tr} (${c.allCount})',
                        c.relFilter.value == null,
                        () => c.relFilter.value = null,
                      ),
                      for (final r in rels)
                        _chip(
                          '${r.label.isEmpty ? 'rel_none'.tr : r.label} (${r.count})',
                          c.relFilter.value == r.label,
                          () => c.relFilter.value = r.label,
                        ),
                    ],
                  ),
                );
              }),
              Obx(() {
                final s = c.stats.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'list_count'.trParams({'args1': '${c.gifts.length}'}),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Obx(
                        () => FilterChip(
                          label: Text('group_by_rel'.tr),
                          selected: c.groupByRel.value,
                          onSelected: (v) => c.groupByRel.value = v,
                          visualDensity: VisualDensity.compact,
                          showCheckmark: false,
                          selectedColor: AppColors.chip,
                          side: BorderSide.none,
                          avatar:
                              const Icon(Icons.view_agenda_outlined, size: 16),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        Money.format(s.totalVnd),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 6),
              Expanded(
                child: Obx(() {
                  final ev = Get.find<EventController>().active.value;
                  if (ev == null) {
                    return EmptyState(
                      icon: Icons.event_busy_rounded,
                      title: 'home_no_event_title'.tr,
                      actionLabel: 'event_create'.tr,
                      onAction: () => Get.toNamed(RouteName.eventEdit),
                    );
                  }
                  if (c.loading.value && c.gifts.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          LoadingSkeleton(),
                          SizedBox(height: 10),
                          LoadingSkeleton(),
                          SizedBox(height: 10),
                          LoadingSkeleton(),
                        ],
                      ),
                    );
                  }
                  if (c.gifts.isEmpty) {
                    final filtering = c.query.value.isNotEmpty ||
                        c.relFilter.value != null ||
                        c.statusFilter.value != null;
                    return EmptyState(
                      icon: filtering
                          ? Icons.search_off_rounded
                          : Icons.mail_outline_rounded,
                      title: filtering
                          ? 'list_no_match'.tr
                          : 'list_empty_title'.tr,
                      message: filtering ? null : 'list_empty_msg'.tr,
                    );
                  }
                  if (c.groupByRel.value) return _grouped();
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 170),
                    itemCount: c.gifts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final g = c.gifts[i];
                      return GiftRow(gift: g, onTap: () => _open(g));
                    },
                  );
                }),
              ),
            ],
          ),
          Positioned(
            right: 20,
            bottom: 108,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'fab_add_full',
                  tooltip: 'add_manual'.tr,
                  backgroundColor: AppColors.chip,
                  foregroundColor: AppColors.primary,
                  elevation: 1,
                  shape: const CircleBorder(),
                  onPressed: () =>
                      _guardEvent(() => Get.toNamed(RouteName.giftEdit)),
                  child: const Icon(Icons.edit_note_rounded),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: 'fab_add_quick',
                  tooltip: 'quick_title'.tr,
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: const CircleBorder(),
                  onPressed: () => _guardEvent(
                    () => showQuickEntry(initialSide: c.sideFilter.value),
                  ),
                  child: const Icon(Icons.bolt_rounded, size: 30),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Danh sách gom theo quan hệ, mỗi mục có tiêu đề + số lượng + tổng đã xác nhận.
  Widget _grouped() {
    final groups = <String, List<GiftRecord>>{};
    for (final g in c.gifts) {
      groups.putIfAbsent((g.relationship ?? '').trim(), () => []).add(g);
    }
    final keys = groups.keys.toList()
      ..sort((a, b) => groups[b]!.length.compareTo(groups[a]!.length));
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 170),
      children: [
        for (final k in keys) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${k.isEmpty ? 'rel_none'.tr : k} · ${groups[k]!.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                Text(
                  Money.format(
                    groups[k]!
                        .where((g) => g.isConfirmed)
                        .fold<int>(0, (a, b) => a + b.amountVnd),
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          for (final g in groups[k]!) ...[
            GiftRow(gift: g, onTap: () => _open(g)),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
          showCheckmark: false,
          selectedColor: AppColors.primary,
          backgroundColor: AppColors.chip,
          side: BorderSide.none,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          labelStyle: TextStyle(
            color: selected ? Colors.white : AppColors.primary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      );
}
