import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../controller/event_controller.dart';
import '../../controller/gift_controller.dart';
import '../../controller/gift_list_controller.dart';
import '../../models/data_models/gift_record.dart';
import '../../models/ui_models/gift_status.dart';
import '../../repository/gift_filter.dart';
import '../../services/application/speech_logic.dart';
import '../../utils/money.dart';
import '../../utils/toast_utils.dart';
import '../../values/app_colors.dart';
import '../../values/route_name.dart';
import '../common_components/components.dart';
import '../common_components/dialogs.dart';
import '../common_components/review_sheet.dart';
import '../common_components/ui_kit.dart';
import 'gift_filter_sheet.dart';
import 'quick_entry_sheet.dart';

/// Mở một bản ghi: chờ xác nhận/lỗi -> sheet duyệt; còn lại -> màn sửa.
void openGift(GiftRecord g) {
  final c = Get.find<GiftController>();
  if (g.status == GiftStatus.pendingReview || g.status == GiftStatus.failed) {
    showReviewSheet(
      g,
      onConfirm: (n, a, r) => c.confirm(g, name: n, amount: a, relationship: r),
      onDelete: () async {
        await c.delete(g.id);
        Toast.show('deleted'.tr);
      },
    );
  } else {
    Get.toNamed(RouteName.giftEdit, arguments: {'id': g.id});
  }
}

/// Chặn thêm khi chưa có sự kiện / sự kiện đã đóng.
void guardActiveEvent(VoidCallback go) {
  final ev = Get.find<EventController>().active.value;
  if (ev == null) {
    Toast.show('need_event_first'.tr);
    Get.toNamed(RouteName.eventEdit, arguments: {'first': true});
  } else if (ev.isClosed) {
    Toast.show('event_closed_no_record'.tr);
  } else {
    go();
  }
}

/// Nút "+" : chọn cách thêm (nhập nhanh / đầy đủ / ghi âm).
Future<void> showAddMenu() async {
  Widget tile(IconData i, String t, String s, String v) => ListTile(
    leading: Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.chip,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(i, color: AppColors.primary),
    ),
    title: Text(t, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(s, style: const TextStyle(fontSize: 12.5)),
    onTap: () => Get.back(result: v),
  );
  final v = await Get.bottomSheet<String>(
    SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          tile(Icons.bolt_rounded, 'add_quick'.tr, 'add_quick_sub'.tr, 'quick'),
          tile(Icons.edit_note_rounded, 'add_full'.tr, 'add_full_sub'.tr, 'full'),
          tile(Icons.mic_rounded, 'add_voice'.tr, 'add_voice_sub'.tr, 'voice'),
          const SizedBox(height: 8),
        ],
      ),
    ),
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
  );
  switch (v) {
    case 'quick':
      guardActiveEvent(() => showQuickEntry());
    case 'full':
      guardActiveEvent(() => Get.toNamed(RouteName.giftEdit));
    case 'voice':
      guardActiveEvent(() => Get.toNamed(RouteName.recording));
  }
}

/// S07 - Danh sách tiền mừng: tìm kiếm (có mic), bộ lọc, nhóm theo ngày, chọn nhiều.
class GiftsTab extends StatefulWidget {
  const GiftsTab({super.key});

  @override
  State<GiftsTab> createState() => _GiftsTabState();
}

class _GiftsTabState extends State<GiftsTab> {
  final TextEditingController _search = TextEditingController();
  final GiftListController c = Get.find<GiftListController>();
  final GiftController giftC = Get.find<GiftController>();
  Timer? _debounce;

  // Tìm kiếm bằng giọng nói (nhận dạng trên máy, tiếng Việt).
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _listening = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _speech.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => c.setQuery(q));
    setState(() {});
  }

  Future<void> _voiceSearch() async {
    if (_listening) {
      await _speech.stop();
      return;
    }
    final perm = await Permission.microphone.request();
    if (!perm.isGranted) {
      Toast.show('mic_denied_title'.tr);
      return;
    }
    final ok = await _speech.initialize(
      onStatus: (s) {
        if ((s == 'done' || s == 'notListening') && mounted) {
          setState(() => _listening = false);
        }
      },
      onError: (_) {
        if (mounted) setState(() => _listening = false);
      },
    );
    if (!ok) {
      Toast.show('rec_err_no_service'.tr);
      return;
    }
    final locales = await _speech.locales();
    final id = pickVietnameseLocale(locales.map((l) => l.localeId));
    if (id == null) {
      Toast.show('rec_err_no_vi'.tr);
      return;
    }
    setState(() => _listening = true);
    await _speech.listen(
      onResult: (r) {
        _search.text = r.recognizedWords;
        _search.selection = TextSelection.collapsed(offset: _search.text.length);
        c.setQuery(r.recognizedWords);
        if (mounted) setState(() {});
      },
      listenOptions: stt.SpeechListenOptions(
        localeId: id,
        listenFor: const Duration(seconds: 12),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
      ),
    );
  }

  // ------------------------------------------------------------- menu

  Future<void> _headerMenu() async {
    final v = await Get.bottomSheet<String>(
      SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.select_all_rounded, color: AppColors.primary),
              title: Text('list_select_all'.tr),
              onTap: () => Get.back(result: 'all'),
            ),
            ListTile(
              leading: const Icon(Icons.pending_actions_rounded, color: AppColors.primary),
              title: Text('list_only_pending'.tr),
              onTap: () => Get.back(result: 'pending'),
            ),
            ListTile(
              leading: const Icon(Icons.sync_rounded, color: AppColors.primary),
              title: Text('sync_now'.tr),
              onTap: () => Get.back(result: 'sync'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
      backgroundColor: AppColors.surface,
    );
    switch (v) {
      case 'all':
        c.selectAll();
      case 'pending':
        c.setFilter(c.filter.value.copyWith(status: GiftStatus.pendingReview));
      case 'sync':
        await giftC.reload();
        await c.reload();
        Toast.show('list_refreshed'.tr);
    }
  }

  Future<void> _pickSide(GiftFilter f) async {
    final v = await _pickFrom<String?>(
      title: 'chip_guest_group'.tr,
      current: f.side,
      options: [
        (null, 'filter_all'.tr),
        (GiftSide.mine, GiftSide.labelKey(GiftSide.mine).tr),
        (GiftSide.parents, GiftSide.labelKey(GiftSide.parents).tr),
      ],
    );
    if (v != null) c.setFilter(f.copyWith(side: v.$1));
  }

  Future<void> _pickRel(GiftFilter f) async {
    final v = await _pickFrom<String?>(
      title: 'chip_relationship'.tr,
      current: f.relationship,
      options: [
        (null, 'filter_all'.tr),
        ('', 'rel_none'.tr),
        for (final r in c.relationships) (r, r),
      ],
    );
    if (v != null) c.setFilter(f.copyWith(relationship: v.$1));
  }

  Future<void> _pickSort(GiftFilter f) async {
    final v = await _pickFrom<GiftSort>(
      title: 'chip_sort'.tr,
      current: f.sort,
      options: [
        (GiftSort.newest, 'sort_newest'.tr),
        (GiftSort.oldest, 'sort_oldest'.tr),
        (GiftSort.amountDesc, 'sort_amount_desc'.tr),
        (GiftSort.amountAsc, 'sort_amount_asc'.tr),
        (GiftSort.nameAsc, 'sort_name'.tr),
      ],
    );
    if (v != null) c.setFilter(f.copyWith(sort: v.$1));
  }

  /// Trả về (giá trị,) để phân biệt "chọn null (tất cả)" với "đóng sheet".
  Future<(T,)?> _pickFrom<T>({
    required String title,
    required T current,
    required List<(T, String)> options,
  }) => Get.bottomSheet<(T,)>(
    SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: Get.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final o in options)
                    ListTile(
                      title: Text(o.$2),
                      trailing: o.$1 == current
                          ? const Icon(Icons.check_rounded, color: AppColors.primary)
                          : null,
                      onTap: () => Get.back(result: (o.$1,)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
  );

  // ----------------------------------------------------------- hành động

  Future<void> _confirmSelected() async {
    final (ok, skipped) = await c.confirmSelected();
    if (ok > 0) Toast.show('list_confirmed'.trParams({'args1': '$ok'}));
    if (skipped > 0) {
      Toast.show('list_confirm_skipped'.trParams({'args1': '$skipped'}));
    }
    if (ok == 0 && skipped == 0) Toast.show('list_nothing_to_confirm'.tr);
  }

  void _editSelected() {
    final sel = c.selectedGifts;
    if (sel.length != 1) {
      Toast.show('list_edit_one'.tr);
      return;
    }
    Get.toNamed(RouteName.giftEdit, arguments: {'id': sel.first.id});
  }

  Future<void> _deleteSelected() async {
    final n = c.selected.length;
    final ok = await confirmDialog(
      title: 'list_delete_title'.tr,
      message: 'list_delete_msg'.trParams({'args1': '$n'}),
      confirmLabel: 'delete'.tr,
      danger: true,
    );
    if (!ok) return;
    final ids = await c.deleteSelected();
    final ctx = Get.context;
    if (ctx == null) return;
    ScaffoldMessenger.of(ctx)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('deleted'.tr),
          action: SnackBarAction(
            label: 'undo'.tr,
            onPressed: () => c.undoDelete(ids),
          ),
        ),
      );
  }

  Future<void> _rowMenu(GiftWithEvent r) async {
    final g = r.gift;
    final pending = g.status != GiftStatus.confirmed;
    final v = await Get.bottomSheet<String>(
      SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: AppColors.primary),
              title: Text('edit'.tr),
              onTap: () => Get.back(result: 'edit'),
            ),
            if (pending)
              ListTile(
                leading: const Icon(Icons.check_circle_outline_rounded, color: AppColors.success),
                title: Text('confirm'.tr),
                onTap: () => Get.back(result: 'confirm'),
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
              title: Text('delete'.tr, style: const TextStyle(color: AppColors.danger)),
              onTap: () => Get.back(result: 'delete'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
      backgroundColor: AppColors.surface,
    );
    switch (v) {
      case 'edit':
        Get.toNamed(RouteName.giftEdit, arguments: {'id': g.id});
      case 'confirm':
        if (g.guestName.trim().isEmpty || g.amountVnd <= 0) {
          openGift(g);
        } else {
          await giftC.confirm(g);
        }
      case 'delete':
        await c.deleteOne(g.id);
        final ctx = Get.context;
        if (ctx != null) {
          ScaffoldMessenger.of(ctx)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text('deleted'.tr),
                action: SnackBarAction(
                  label: 'undo'.tr,
                  onPressed: () => c.undoDelete([g.id]),
                ),
              ),
            );
        }
    }
  }

  // --------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Stack(
      children: [
        Column(
          children: [
            _header(),
            Expanded(
              child: Obx(() {
                final f = c.filter.value;
                final items = c.items.toList();
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 190),
                  children: [
                    _searchRow(f),
                    const SizedBox(height: 10),
                    _chips(f),
                    const SizedBox(height: 10),
                    _summary(),
                    const SizedBox(height: 8),
                    if (c.loading.value && items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(30),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (items.isEmpty)
                      SizedBox(
                        height: 280,
                        child: EmptyState(
                          icon: Icons.inbox_outlined,
                          title: f.hasAny
                              ? 'gifts_no_result'.tr
                              : 'gifts_empty_title'.tr,
                          message: f.hasAny ? null : 'gifts_empty_msg'.tr,
                          actionLabel: f.hasAny ? 'filter_reset'.tr : null,
                          onAction: f.hasAny
                              ? () {
                                  _search.clear();
                                  c.setFilter(const GiftFilter());
                                }
                              : null,
                        ),
                      )
                    else
                      ..._groups(items),
                  ],
                );
              }),
            ),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 178,
          child: AddFab(onTap: showAddMenu),
        ),
        Positioned(left: 16, right: 16, bottom: 100, child: _selectionBar()),
      ],
    ),
  );

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 8, 8),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'gifts_title'.tr,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              Text(
                'gifts_subtitle'.tr,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
          child: IconButton(
            tooltip: 'set_export'.tr,
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.file_download_outlined, color: AppColors.primary, size: 22),
            onPressed: () => Get.toNamed(RouteName.export),
          ),
        ),
        IconButton(
          tooltip: 'more'.tr,
          icon: const Icon(Icons.more_vert_rounded),
          onPressed: _headerMenu,
        ),
      ],
    ),
  );

  Widget _searchRow(GiftFilter f) => Row(
    children: [
      Expanded(
        child: TextField(
          controller: _search,
          onChanged: _onSearch,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'gifts_search_hint'.tr,
            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
            suffixIcon: _search.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () {
                      _search.clear();
                      c.setQuery('');
                      setState(() {});
                    },
                  )
                : IconButton(
                    tooltip: 'gifts_search_voice'.tr,
                    icon: Icon(
                      _listening ? Icons.graphic_eq_rounded : Icons.mic_rounded,
                      color: AppColors.primary,
                    ),
                    onPressed: _voiceSearch,
                  ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      GestureDetector(
        onTap: () => showGiftFilterSheet(c),
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: f.sheetActiveCount > 0 ? AppColors.chip : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: f.sheetActiveCount > 0 ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Badge(
            isLabelVisible: f.sheetActiveCount > 0,
            label: Text('${f.sheetActiveCount}'),
            child: const Icon(Icons.tune_rounded, color: AppColors.primary),
          ),
        ),
      ),
    ],
  );

  Widget _chips(GiftFilter f) {
    final noChip = f.side == null && f.relationship == null && f.status == null;
    Widget chip({
      required String label,
      required bool selected,
      required VoidCallback onTap,
      IconData? icon,
      bool dropdown = false,
    }) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: selected ? Colors.white : AppColors.primary),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              if (dropdown) ...[
                const SizedBox(width: 2),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip(
            label: '${'filter_all'.tr} (${c.totalCount.value})',
            selected: noChip,
            onTap: () => c.setFilter(
              f.copyWith(side: null, relationship: null, status: null),
            ),
          ),
          chip(
            label: f.side == null
                ? 'chip_guest_group'.tr
                : GiftSide.labelKey(f.side!).tr,
            icon: Icons.groups_outlined,
            selected: f.side != null,
            dropdown: true,
            onTap: () => _pickSide(f),
          ),
          chip(
            label: f.relationship == null
                ? 'chip_relationship'.tr
                : (f.relationship!.isEmpty ? 'rel_none'.tr : f.relationship!),
            icon: Icons.diversity_3_rounded,
            selected: f.relationship != null,
            dropdown: true,
            onTap: () => _pickRel(f),
          ),
          chip(
            label: 'chip_sort'.tr,
            icon: Icons.swap_vert_rounded,
            selected: f.sort != GiftSort.newest,
            dropdown: true,
            onTap: () => _pickSort(f),
          ),
        ],
      ),
    );
  }

  Widget _summary() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFEFE4FF), Color(0xFFE2D2FC)],
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        const Text('💌', style: TextStyle(fontSize: 34)),
        const SizedBox(width: 10),
        _sum(Icons.mail_outline_rounded, '${c.envelopeCount}', 'kpi_envelopes'.tr),
        _divider(),
        _sum(Icons.groups_outlined, '${c.guestCount}', 'kpi_guests'.tr),
        _divider(),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  Money.format(c.totalVnd),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
              Text(
                'home_total'.tr,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _sum(IconData i, String v, String l) => Expanded(
    flex: 2,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(v, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        Text(l, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ],
    ),
  );

  Widget _divider() => Container(
    width: 1,
    height: 30,
    margin: const EdgeInsets.symmetric(horizontal: 8),
    color: AppColors.primary.withValues(alpha: 0.2),
  );

  List<Widget> _groups(List<GiftWithEvent> items) {
    final out = <Widget>[];
    DateTime? day;
    int dayTotal(DateTime d) => items
        .where((r) {
          final t = r.gift.createdAt;
          return t.year == d.year && t.month == d.month && t.day == d.day;
        })
        .where((r) => r.gift.status == GiftStatus.confirmed)
        .fold(0, (a, r) => a + r.gift.amountVnd);
    // Khi sắp theo tiền/tên thì không nhóm theo ngày.
    final byDay = c.filter.value.sort == GiftSort.newest ||
        c.filter.value.sort == GiftSort.oldest;
    for (final r in items) {
      final t = r.gift.createdAt;
      final d = DateTime(t.year, t.month, t.day);
      if (byDay && (day == null || d != day)) {
        day = d;
        out.add(_dayHeader(d, dayTotal(d)));
      }
      out.add(_row(r));
      out.add(const SizedBox(height: 8));
    }
    return out;
  }

  Widget _dayHeader(DateTime d, int total) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(d).inDays;
    final date = DateFormat('dd/MM/yyyy').format(d);
    final label = diff == 0
        ? '${'day_today'.tr} - $date'
        : (diff == 1 ? '${'day_yesterday'.tr} - $date' : date);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Row(
        children: [
          const Icon(Icons.calendar_month_outlined, size: 18, color: AppColors.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
          ),
          Text(
            '${'sum_total'.tr}: ${Money.format(total)}',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(GiftWithEvent r) {
    final g = r.gift;
    final sel = c.isSelected(g.id);
    final unknown = g.guestName.trim().isEmpty;
    final chip = switch (g.status) {
      GiftStatus.pendingReview => (
        'status_pending'.tr,
        AppColors.warning,
        AppColors.warningBg,
      ),
      GiftStatus.failed => (
        'status_failed'.tr,
        AppColors.danger,
        AppColors.dangerBg,
      ),
      GiftStatus.confirmed when g.source == GiftSource.voice => (
        'status_confirmed'.tr,
        AppColors.success,
        AppColors.successBg,
      ),
      _ => null,
    };
    return GestureDetector(
      onTap: () => c.selected.isNotEmpty ? c.toggle(g.id) : openGift(g),
      onLongPress: () => c.toggle(g.id),
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 8, 2, 8),
        decoration: BoxDecoration(
          color: sel ? AppColors.chip : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: sel ? AppColors.primary : AppColors.border.withValues(alpha: 0.7),
          ),
        ),
        child: Row(
          children: [
            Checkbox(
              value: sel,
              activeColor: AppColors.primary,
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
              onChanged: (_) => c.toggle(g.id),
            ),
            InitialsAvatar(name: unknown ? '?' : g.guestName, size: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    unknown ? 'guest_unknown'.tr : g.guestName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      fontStyle: unknown ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.groups_outlined, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          (g.relationship ?? '').trim().isEmpty
                              ? 'rel_none'.tr
                              : g.relationship!.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Money.format(g.amountVnd),
                  style: TextStyle(
                    color: g.status == GiftStatus.confirmed
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                if (chip != null)
                  StatusPill(label: chip.$1, color: chip.$2, bg: chip.$3)
                else
                  Text(
                    DateFormat('HH:mm').format(g.createdAt),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            IconButton(
              tooltip: 'more'.tr,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.more_vert_rounded, size: 20),
              onPressed: () => _rowMenu(r),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectionBar() => Obx(() {
    final n = c.selected.length;
    final enabled = n > 0;
    Widget action(IconData i, String l, VoidCallback onTap, {Color? color}) =>
        Expanded(
          child: GestureDetector(
            onTap: enabled ? onTap : null,
            child: Opacity(
              opacity: enabled ? 1 : 0.45,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(i, size: 18, color: color ?? AppColors.primary),
                  const SizedBox(width: 3),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        l,
                        maxLines: 1,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: color ?? AppColors.text,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: n > 0 ? c.clearSelection : c.selectAll,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.chip,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text(
                    '${'list_selected'.tr}: $n',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          action(Icons.check_circle_outline_rounded, 'confirm'.tr, _confirmSelected),
          action(Icons.edit_outlined, 'edit'.tr, _editSelected),
          action(Icons.delete_outline_rounded, 'delete'.tr, _deleteSelected,
              color: AppColors.danger),
        ],
      ),
    );
  });
}
