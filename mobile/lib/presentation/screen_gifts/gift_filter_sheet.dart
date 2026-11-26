import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controller/gift_list_controller.dart';
import '../../repository/gift_filter.dart';
import '../../utils/money.dart';
import '../../utils/toast_utils.dart';
import '../../values/app_colors.dart';
import '../common_components/components.dart';
import '../common_components/money_input_formatter.dart';
import '../common_components/ui_kit.dart';

/// Bottom sheet "Bộ lọc": loại giao dịch, loại sự kiện, thời gian, khoảng tiền.
Future<void> showGiftFilterSheet(GiftListController c) => Get.bottomSheet(
  _FilterSheet(c),
  isScrollControlled: true,
  backgroundColor: AppColors.background,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
  ),
);

enum _Range { all, d7, d30, year, custom }

class _FilterSheet extends StatefulWidget {
  const _FilterSheet(this.c);
  final GiftListController c;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late GiftFilter _f = widget.c.filter.value;
  final TextEditingController _min = TextEditingController();
  final TextEditingController _max = TextEditingController();
  _Range _range = _Range.all;
  int? _count;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (_f.minAmount != null) {
      _min.text = Money.format(_f.minAmount!, symbol: false);
    }
    if (_f.maxAmount != null) {
      _max.text = Money.format(_f.maxAmount!, symbol: false);
    }
    _range = _inferRange();
    _refreshCount();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  _Range _inferRange() {
    if (_f.from == null && _f.to == null) return _Range.all;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    bool same(DateTime? a, DateTime b) =>
        a != null && a.year == b.year && a.month == b.month && a.day == b.day;
    if (same(_f.to, today)) {
      if (same(_f.from, today.subtract(const Duration(days: 6)))) {
        return _Range.d7;
      }
      if (same(_f.from, today.subtract(const Duration(days: 29)))) {
        return _Range.d30;
      }
      if (same(_f.from, DateTime(now.year))) return _Range.year;
    }
    return _Range.custom;
  }

  void _refreshCount() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () async {
      final n = await widget.c.countFor(_f);
      if (mounted) setState(() => _count = n);
    });
  }

  void _update(GiftFilter f) {
    setState(() => _f = f);
    _refreshCount();
  }

  void _setRange(_Range r) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (r) {
      case _Range.all:
        _range = r;
        _update(_f.copyWith(from: null, to: null));
      case _Range.d7:
        _range = r;
        _update(_f.copyWith(
          from: today.subtract(const Duration(days: 6)),
          to: today,
        ));
      case _Range.d30:
        _range = r;
        _update(_f.copyWith(
          from: today.subtract(const Duration(days: 29)),
          to: today,
        ));
      case _Range.year:
        _range = r;
        _update(_f.copyWith(from: DateTime(now.year), to: today));
      case _Range.custom:
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2000),
          lastDate: DateTime(now.year + 2),
          initialDateRange: _f.from != null && _f.to != null
              ? DateTimeRange(start: _f.from!, end: _f.to!)
              : null,
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: Theme.of(ctx).colorScheme.copyWith(
                primary: AppColors.primary,
              ),
            ),
            child: child!,
          ),
        );
        if (picked == null) return;
        _range = r;
        _update(_f.copyWith(from: picked.start, to: picked.end));
    }
  }

  void _amounts() {
    final lo = Money.parse(_min.text);
    final hi = Money.parse(_max.text);
    _update(_f.copyWith(minAmount: lo, maxAmount: hi));
  }

  void _reset() {
    _min.clear();
    _max.clear();
    _range = _Range.all;
    _update(
      _f.copyWith(
        eventType: null,
        from: null,
        to: null,
        minAmount: null,
        maxAmount: null,
      ),
    );
  }

  void _apply() {
    final lo = _f.minAmount;
    final hi = _f.maxAmount;
    if (lo != null && hi != null && lo > hi) {
      Toast.show('filter_amount_invalid'.tr);
      return;
    }
    widget.c.setFilter(_f);
    Get.back();
  }

  String _rangeLabel(_Range r) => switch (r) {
    _Range.all => 'filter_time_all'.tr,
    _Range.d7 => 'filter_time_7'.tr,
    _Range.d30 => 'filter_time_30'.tr,
    _Range.year => 'filter_time_year'.tr,
    _Range.custom => 'filter_time_custom'.tr,
  };

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: h * 0.92),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'filter_title'.tr,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'close'.tr,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: Get.back,
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                children: [
                  _section('filter_type'.tr, _typeRow()),
                  const SizedBox(height: 10),
                  _section('filter_event'.tr, _eventList()),
                  const SizedBox(height: 10),
                  _section('filter_time'.tr, _timeChips()),
                  const SizedBox(height: 10),
                  _section('filter_amount'.tr, _amountRow()),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                14 + MediaQuery.of(context).padding.bottom,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      label: 'filter_reset'.tr,
                      icon: Icons.refresh_rounded,
                      onPressed: _reset,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PrimaryButton(
                      label: _count == null
                          ? 'filter_apply'.tr
                          : '${'filter_apply'.tr} ($_count)',
                      onPressed: _apply,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, Widget child) => SoftCard(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );

  Widget _typeRow() => Row(
    children: [
      Expanded(
        child: _selectable(
          selected: true,
          icon: Icons.mail_outline_rounded,
          label: 'filter_received'.tr,
          onTap: () {},
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Opacity(
          opacity: 0.5,
          child: _selectable(
            selected: false,
            icon: Icons.card_giftcard_rounded,
            label: 'filter_given'.tr,
            onTap: () => Toast.show('filter_given_soon'.tr),
          ),
        ),
      ),
    ],
  );

  Widget _selectable({
    required bool selected,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
      decoration: BoxDecoration(
        color: selected ? AppColors.chip : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (selected)
            const Icon(Icons.check_rounded, color: AppColors.primary, size: 18),
          if (selected) const SizedBox(width: 4),
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? AppColors.primary : AppColors.text,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _eventList() {
    Widget row(String? type, IconData icon, String label) {
      final sel = _f.eventType == type;
      return GestureDetector(
        onTap: () => _update(_f.copyWith(eventType: type)),
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          decoration: BoxDecoration(
            color: sel ? AppColors.chip : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                    color: sel ? AppColors.primary : AppColors.text,
                  ),
                ),
              ),
              Icon(
                sel
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: sel ? AppColors.primary : AppColors.border,
              ),
            ],
          ),
        ),
      );
    }

    const icons = <String, IconData>{
      'wedding': Icons.favorite_border_rounded,
      'engagement': Icons.local_florist_outlined,
      'birthday': Icons.cake_outlined,
      'housewarming': Icons.home_outlined,
      'baby_month': Icons.child_care_rounded,
      'other': Icons.more_horiz_rounded,
    };
    return Column(
      children: [
        row(null, Icons.all_inbox_rounded, 'filter_all_events'.tr),
        for (final t in EventTypeInfo.all)
          row(t.type, icons[t.type] ?? Icons.event_rounded, t.labelKey.tr),
      ],
    );
  }

  Widget _timeChips() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final r in _Range.values)
        GestureDetector(
          onTap: () => _setRange(r),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: _range == r ? AppColors.chip : AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _range == r ? AppColors.primary : AppColors.border,
                width: _range == r ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (r == _Range.custom) ...[
                  const Icon(Icons.calendar_today_outlined,
                      size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                ],
                Text(
                  r == _Range.custom && _range == r && _f.from != null
                      ? '${_f.from!.day}/${_f.from!.month} - ${_f.to?.day}/${_f.to?.month}'
                      : _rangeLabel(r),
                  style: TextStyle(
                    color: _range == r ? AppColors.primary : AppColors.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
    ],
  );

  Widget _amountRow() => Row(
    children: [
      Expanded(child: _amountField('filter_from'.tr, _min, '0 đ')),
      const SizedBox(width: 12),
      Expanded(child: _amountField('filter_to'.tr, _max, '100.000.000 đ')),
    ],
  );

  Widget _amountField(String label, TextEditingController c, String hint) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: c,
            keyboardType: TextInputType.number,
            inputFormatters: [MoneyInputFormatter()],
            onChanged: (_) => _amounts(),
            decoration: InputDecoration(hintText: hint),
          ),
        ],
      );
}
