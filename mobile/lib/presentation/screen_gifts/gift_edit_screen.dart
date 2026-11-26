import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../configs/app_config.dart';
import '../../controller/event_controller.dart';
import '../../controller/gift_controller.dart';
import '../../models/data_models/gift_record.dart';
import '../../models/ui_models/gift_status.dart';
import '../../utils/date_fmt.dart';
import '../../utils/money.dart';
import '../../utils/toast_utils.dart';
import '../../values/app_colors.dart';
import '../common_components/components.dart';
import '../common_components/dialogs.dart';
import '../common_components/money_input_formatter.dart';

/// S08 Chỉnh sửa bản ghi (có `id`) + X02 Nhập tay (không có `id`).
class GiftEditScreen extends StatefulWidget {
  const GiftEditScreen({super.key});

  @override
  State<GiftEditScreen> createState() => _GiftEditScreenState();
}

class _GiftEditScreenState extends State<GiftEditScreen> {
  final GiftController _c = Get.find<GiftController>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _rel = TextEditingController();
  final TextEditingController _note = TextEditingController();

  GiftRecord? _gift;
  String _side = GiftSide.mine;
  bool _loading = true;
  bool _saving = false;
  String? _nameErr;
  String? _amountErr;

  bool get _isEdit => _gift != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = (Get.arguments as Map?)?['id'] as String?;
    if (id != null) {
      final g = _c.gifts.firstWhereOrNull((x) => x.id == id);
      if (g != null) {
        _gift = g;
        _name.text = g.guestName;
        _amount.text =
            g.amountVnd > 0 ? Money.format(g.amountVnd, symbol: false) : '';
        _rel.text = g.relationship ?? '';
        _note.text = g.note ?? '';
        _side = g.side;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _rel.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final amount = Money.parse(_amount.text);
    setState(() {
      _nameErr = name.isEmpty ? 'err_name'.tr : null;
      _amountErr = (amount == null || amount <= 0)
          ? 'err_amount'.tr
          : (amount > AppConfig.maxAmountVnd ? 'err_amount_max'.tr : null);
    });
    if (_nameErr != null || _amountErr != null) return;

    setState(() => _saving = true);
    try {
      // BR06: cảnh báo trùng, người dùng quyết định (không chặn cứng).
      final dups = await _c.duplicatesOf(name, amount!, excludeId: _gift?.id);
      if (dups.isNotEmpty) {
        final keep = await confirmDialog(
          title: 'dup_title'.tr,
          message: 'dup_msg'.tr,
          confirmLabel: 'dup_keep'.tr,
        );
        if (!keep) return;
      }
      if (_isEdit) {
        await _c.updateGift(
          _gift!,
          name: name,
          amount: amount,
          relationship: _rel.text,
          note: _note.text,
          side: _side,
          status: GiftStatus.confirmed,
        );
      } else {
        await _c.addManual(
          name: name,
          amount: amount,
          relationship: _rel.text,
          note: _note.text,
          side: _side,
          warnings: dups.isNotEmpty ? const ['possible_duplicate'] : const [],
        );
      }
      Toast.show('saved'.tr);
      Get.back();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final g = _gift!;
    final ok = await confirmDialog(
      title: 'delete_gift_title'.tr,
      message: 'delete_gift_msg'.tr,
      confirmLabel: 'delete'.tr,
      danger: true,
    );
    if (!ok) return;
    await _c.delete(g.id);
    Get.back();
    showUndoSnack('deleted'.tr, () => _c.undoDelete(g.id));
  }

  @override
  Widget build(BuildContext context) {
    final ev = Get.find<EventController>().active.value;
    return GradientScaffold(
      appBar: AppHeader(title: _isEdit ? 'edit_title'.tr : 'add_manual'.tr),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (ev != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: StatusPill(
                          label: ev.name,
                          color: AppColors.primary,
                          bg: AppColors.chip,
                        ),
                      ),
                    FieldLabel('field_side'.tr),
                    SideSelector(
                      value: _side,
                      onChanged: (v) =>
                          setState(() => _side = v ?? GiftSide.mine),
                    ),
                    FieldLabel('field_guest'.tr),
                    IconField(
                      controller: _name,
                      icon: Icons.person_outline_rounded,
                      hint: 'hint_guest'.tr,
                      errorText: _nameErr,
                      autofocus: !_isEdit,
                    ),
                    FieldLabel('field_amount'.tr),
                    IconField(
                      controller: _amount,
                      icon: Icons.payments_outlined,
                      hint: '0',
                      keyboardType: TextInputType.number,
                      inputFormatters: [MoneyInputFormatter()],
                      errorText: _amountErr,
                      suffix: const Padding(
                        padding: EdgeInsets.only(right: 16),
                        child: Center(
                          widthFactor: 1,
                          child: Text(
                            'đ',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ),
                    FieldLabel('field_relationship'.tr),
                    IconField(
                      controller: _rel,
                      icon: Icons.diversity_3_rounded,
                      hint: 'hint_relationship'.tr,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final r in kRelationshipPresets)
                          ActionChip(
                            label: Text(r),
                            onPressed: () => setState(() => _rel.text = r),
                            backgroundColor: AppColors.chip,
                            side: BorderSide.none,
                            labelStyle: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                    FieldLabel('field_note'.tr),
                    IconField(
                      controller: _note,
                      hint: 'hint_note'.tr,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    if (_isEdit) ...[
                      FieldLabel('field_date'.tr),
                      SoftCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 20,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 12),
                            Text(DateFmt.dateTime(_gift!.createdAt)),
                          ],
                        ),
                      ),
                      FieldLabel('field_source'.tr),
                      SoftCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _gift!.source == GiftSource.voice
                                  ? Icons.mic_rounded
                                  : Icons.edit_rounded,
                              size: 20,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _gift!.source == GiftSource.voice
                                  ? 'source_voice'.tr
                                  : 'source_manual'.tr,
                            ),
                          ],
                        ),
                      ),
                      if ((_gift!.transcript ?? '').isNotEmpty) ...[
                        FieldLabel('review_transcript'.tr),
                        Text(
                          '"${_gift!.transcript}"',
                          style: const TextStyle(
                            fontStyle: FontStyle.italic,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        if (_isEdit) ...[
                          Expanded(
                            child: SecondaryButton(
                              label: 'delete'.tr,
                              danger: true,
                              onPressed: _delete,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          flex: 2,
                          child: PrimaryButton(
                            label: 'save'.tr,
                            loading: _saving,
                            onPressed: _save,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
