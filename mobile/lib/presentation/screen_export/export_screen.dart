import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controller/event_controller.dart';
import '../../models/data_models/gift_record.dart';
import '../../repository/gift_repository.dart';
import '../../services/application/export_service.dart';
import '../../utils/date_fmt.dart';
import '../../utils/money.dart';
import '../../utils/toast_utils.dart';
import '../../values/app_colors.dart';
import '../common_components/components.dart';

/// S10 - Xuất Excel: chọn cột, khoảng thời gian, có/không gồm chờ xác nhận.
class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

enum _Range { all, d7, d30, custom }

class _ExportScreenState extends State<ExportScreen> {
  final GiftRepository _repo = Get.find<GiftRepository>();
  final ExportService _svc = ExportService();
  final ExportColumns _cols = ExportColumns();
  bool _includePending = false;
  _Range _range = _Range.all;
  DateTimeRange? _custom;
  bool _busy = false;
  String? _error;
  List<GiftRecord> _preview = const [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  (DateTime?, DateTime?) get _window {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_range) {
      case _Range.all:
        return (null, null);
      case _Range.d7:
        return (today.subtract(const Duration(days: 6)), null);
      case _Range.d30:
        return (today.subtract(const Duration(days: 29)), null);
      case _Range.custom:
        return (
          _custom?.start,
          _custom == null ? null : _custom!.end.add(const Duration(days: 1)),
        );
    }
  }

  Future<void> _refresh() async {
    final ev = Get.find<EventController>().active.value;
    if (ev == null) return;
    final w = _window;
    final list = await _repo.forExport(
      ev.id,
      from: w.$1,
      to: w.$2,
      includePending: _includePending,
    );
    if (mounted) setState(() => _preview = list);
  }

  Future<void> _pickRange() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _custom,
    );
    if (r != null) {
      _custom = r;
      setState(() => _range = _Range.custom);
      _refresh();
    }
  }

  Future<void> _export() async {
    final ev = Get.find<EventController>().active.value;
    if (ev == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await _svc.build(
        event: ev,
        gifts: _preview,
        columns: _cols,
        includePending: _includePending,
        labels: {
          'sheet': 'GiftFlow',
          'no': 'export_col_no'.tr,
          'guest': 'field_guest'.tr,
          'amount': 'field_amount'.tr,
          'relationship': 'field_relationship'.tr,
          'side': 'export_col_side'.tr,
          'side_mine': 'side_mine'.tr,
          'side_parents': 'side_parents'.tr,
          'note': 'field_note'.tr,
          'status': 'export_col_status'.tr,
          'confirmed': 'status_confirmed'.tr,
          'pending': 'status_pending'.tr,
          'total': 'export_total'.tr,
        },
      );
      await _svc.share(res, subject: ev.name);
      Toast.show('export_done'.trParams({'args1': '${res.rows}'}));
    } catch (_) {
      setState(() => _error = 'export_failed'.tr);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ev = Get.find<EventController>().active.value;
    final total = _preview
        .where((g) => g.isConfirmed)
        .fold<int>(0, (a, b) => a + b.amountVnd);
    final noCol = !_cols.guest && !_cols.amount && !_cols.relationship && !_cols.side && !_cols.note;
    return GradientScaffold(
      appBar: AppHeader(title: 'export_title'.tr),
      body: SafeArea(
        child: ev == null
            ? EmptyState(
                icon: Icons.event_busy_rounded,
                title: 'home_no_event_title'.tr,
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  Center(
                    child: Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        color: AppColors.successBg,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.table_view_rounded,
                        size: 52,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'export_headline'.tr,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ev.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  FieldLabel('export_columns'.tr),
                  SoftCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        _check('export_col_guest'.tr, _cols.guest,
                            (v) => setState(() => _cols.guest = v)),
                        _check('export_col_amount'.tr, _cols.amount,
                            (v) => setState(() => _cols.amount = v)),
                        _check('export_col_rel'.tr, _cols.relationship,
                            (v) => setState(() => _cols.relationship = v)),
                        _check('export_col_side'.tr, _cols.side,
                            (v) => setState(() => _cols.side = v)),
                        _check('field_note'.tr, _cols.note,
                            (v) => setState(() => _cols.note = v)),
                      ],
                    ),
                  ),
                  FieldLabel('export_range'.tr),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _rangeChip('range_all'.tr, _Range.all),
                      _rangeChip('range_7'.tr, _Range.d7),
                      _rangeChip('range_30'.tr, _Range.d30),
                      ChoiceChip(
                        label: Text(
                          _range == _Range.custom && _custom != null
                              ? '${DateFmt.display(DateFmt.iso(_custom!.start))} - '
                                    '${DateFmt.display(DateFmt.iso(_custom!.end))}'
                              : 'range_custom'.tr,
                        ),
                        selected: _range == _Range.custom,
                        onSelected: (_) => _pickRange(),
                        showCheckmark: false,
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.chip,
                        side: BorderSide.none,
                        labelStyle: TextStyle(
                          color: _range == _Range.custom
                              ? Colors.white
                              : AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SoftCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: SwitchListTile(
                      value: _includePending,
                      activeThumbColor: AppColors.primary,
                      title: Text('export_include_pending'.tr),
                      subtitle: Text('export_include_pending_note'.tr),
                      onChanged: (v) {
                        setState(() => _includePending = v);
                        _refresh();
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  SoftCard(
                    child: Row(
                      children: [
                        const Icon(Icons.fact_check_outlined,
                            color: AppColors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'export_preview'.trParams({
                              'args1': '${_preview.length}',
                              'args2': Money.format(total),
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    ErrorBanner(
                      message: _error!,
                      icon: Icons.error_outline_rounded,
                    ),
                  ],
                  const SizedBox(height: 20),
                  PrimaryButton(
                    label: 'export_button'.tr,
                    icon: Icons.download_rounded,
                    loading: _busy,
                    onPressed: (_preview.isEmpty || noCol) ? null : _export,
                  ),
                  if (_preview.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        'export_empty'.tr,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _check(String label, bool v, ValueChanged<bool> on) => CheckboxListTile(
    value: v,
    onChanged: (x) => on(x ?? false),
    title: Text(label),
    activeColor: AppColors.primary,
    controlAffinity: ListTileControlAffinity.leading,
    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
  );

  Widget _rangeChip(String label, _Range r) => ChoiceChip(
    label: Text(label),
    selected: _range == r,
    onSelected: (_) {
      setState(() => _range = r);
      _refresh();
    },
    showCheckmark: false,
    selectedColor: AppColors.primary,
    backgroundColor: AppColors.chip,
    side: BorderSide.none,
    labelStyle: TextStyle(
      color: _range == r ? Colors.white : AppColors.primary,
      fontWeight: FontWeight.w700,
    ),
  );
}
