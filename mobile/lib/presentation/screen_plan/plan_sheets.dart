import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controller/plan_controller.dart';
import '../../models/data_models/plan_models.dart';
import '../../models/ui_models/gift_status.dart';
import '../../utils/date_fmt.dart';
import '../../utils/money.dart';
import '../../utils/toast_utils.dart';
import '../../values/app_colors.dart';
import '../common_components/components.dart';
import '../common_components/money_input_formatter.dart';

Future<void> _sheet(Widget child) => Get.bottomSheet(
  child,
  isScrollControlled: true,
  backgroundColor: AppColors.surface,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
);

/// Thêm / sửa một khoản chi.
Future<void> showPlanItemSheet(PlanController c, {PlanItem? item, String? category}) =>
    _sheet(_ItemSheet(c, item: item, category: category));

/// Thêm / sửa một khách mời dự kiến.
Future<void> showPlanGuestSheet(PlanController c, {PlanGuest? guest}) =>
    _sheet(_GuestSheet(c, guest: guest));

/// Dán nhiều khách (mỗi dòng một người).
Future<void> showPlanBulkGuestSheet(PlanController c) => _sheet(_BulkSheet(c));

/// Đặt tổng ngân sách.
Future<void> showBudgetDialog(PlanController c) async {
  final ctl = TextEditingController(
    text: c.budgetVnd == null ? '' : Money.format(c.budgetVnd!, symbol: false),
  );
  final res = await Get.dialog<int>(
    AlertDialog(
      title: Text('plan_budget_title'.tr),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'plan_budget_hint'.tr,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: ctl,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [MoneyInputFormatter()],
            decoration: InputDecoration(
              hintText: '300.000.000',
              suffixText: 'đ',
              labelText: 'plan_budget_total'.tr,
            ),
          ),
        ],
      ),
      actions: [
        if (c.budgetVnd != null)
          TextButton(
            onPressed: () => Get.back(result: 0),
            child: Text(
              'plan_budget_clear'.tr,
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        TextButton(onPressed: Get.back, child: Text('cancel'.tr)),
        TextButton(
          onPressed: () => Get.back(result: Money.parse(ctl.text) ?? 0),
          child: Text('save'.tr),
        ),
      ],
    ),
  );
  if (res == null) return;
  await c.setBudget(res);
}

// ------------------------------------------------------------------ khoản chi

class _ItemSheet extends StatefulWidget {
  const _ItemSheet(this.c, {this.item, this.category});
  final PlanController c;
  final PlanItem? item;
  final String? category;

  @override
  State<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<_ItemSheet> {
  late String _cat = widget.item?.category ?? widget.category ?? 'venue';
  late final TextEditingController _name = TextEditingController(
    text: widget.item?.name ?? '',
  );
  late final TextEditingController _planned = TextEditingController(
    text: (widget.item?.plannedVnd ?? 0) > 0
        ? Money.format(widget.item!.plannedVnd, symbol: false)
        : '',
  );
  late final TextEditingController _paid = TextEditingController(
    text: (widget.item?.paidVnd ?? 0) > 0
        ? Money.format(widget.item!.paidVnd, symbol: false)
        : '',
  );
  late final TextEditingController _vendor = TextEditingController(
    text: widget.item?.vendor ?? '',
  );
  late final TextEditingController _note = TextEditingController(
    text: widget.item?.note ?? '',
  );
  String? _due;
  String? _nameErr;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _due = widget.item?.dueDate;
  }

  @override
  void dispose() {
    _name.dispose();
    _planned.dispose();
    _paid.dispose();
    _vendor.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final init = DateTime.tryParse(_due ?? '') ?? DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _due = DateFmt.iso(d));
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameErr = 'plan_err_name'.tr);
      return;
    }
    setState(() => _saving = true);
    final planned = Money.parse(_planned.text) ?? 0;
    final paid = Money.parse(_paid.text) ?? 0;
    final base = widget.item ??
        widget.c.newItem(category: _cat, name: name);
    await widget.c.saveItem(
      base.copyWith(
        category: _cat,
        name: name,
        plannedVnd: planned,
        paidVnd: paid,
        vendor: _vendor.text,
        dueDate: _due,
        note: _note.text,
      ),
    );
    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    final planned = Money.parse(_planned.text) ?? 0;
    final paid = Money.parse(_paid.text) ?? 0;
    final status = PayStatus.derive(planned, paid);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: Get.height * 0.9),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.of(context).viewInsets.bottom +
              MediaQuery.of(context).padding.bottom +
              16,
        ),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.item == null ? 'plan_item_add'.tr : 'plan_item_edit'.tr,
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
              ),
              FieldLabel('plan_category'.tr),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final c in PlanCategory.all)
                    ChoiceChip(
                      avatar: Text(c.emoji),
                      label: Text(c.labelKey.tr),
                      selected: _cat == c.key,
                      onSelected: (_) => setState(() => _cat = c.key),
                      showCheckmark: false,
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.chip,
                      side: BorderSide.none,
                      labelStyle: TextStyle(
                        color: _cat == c.key ? Colors.white : AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
              FieldLabel('plan_item_name'.tr),
              IconField(
                controller: _name,
                icon: Icons.label_outline_rounded,
                hint: 'plan_item_name_hint'.tr,
                errorText: _nameErr,
                onChanged: (_) {
                  if (_nameErr != null) setState(() => _nameErr = null);
                },
              ),
              FieldLabel('plan_planned'.tr),
              IconField(
                controller: _planned,
                icon: Icons.payments_outlined,
                hint: '0',
                keyboardType: TextInputType.number,
                inputFormatters: [MoneyInputFormatter()],
                onChanged: (_) => setState(() {}),
                suffix: const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: Center(
                    widthFactor: 1,
                    child: Text('đ', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
              FieldLabel('plan_paid'.tr),
              IconField(
                controller: _paid,
                icon: Icons.task_alt_rounded,
                hint: '0',
                keyboardType: TextInputType.number,
                inputFormatters: [MoneyInputFormatter()],
                onChanged: (_) => setState(() {}),
                suffix: const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: Center(
                    widthFactor: 1,
                    child: Text('đ', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    payStatusPill(status, paid: paid, planned: planned),
                    const SizedBox(width: 8),
                    if (paid > planned && planned > 0)
                      Text(
                        'plan_paid_over'.tr,
                        style: TextStyle(
                          color: AppColors.warning,
                          fontSize: 12.5,
                        ),
                      ),
                  ],
                ),
              ),
              FieldLabel('plan_vendor'.tr),
              IconField(
                controller: _vendor,
                icon: Icons.storefront_outlined,
                hint: 'plan_vendor_hint'.tr,
              ),
              FieldLabel('plan_due'.tr),
              SoftCard(
                onTap: _pickDue,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Icon(Icons.event_outlined, color: AppColors.textSecondary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _due == null ? 'plan_due_none'.tr : DateFmt.display(_due!),
                      ),
                    ),
                    if (_due != null)
                      GestureDetector(
                        onTap: () => setState(() => _due = null),
                        child: const Icon(Icons.close_rounded, size: 20),
                      ),
                  ],
                ),
              ),
              FieldLabel('plan_note'.tr),
              IconField(
                controller: _note,
                icon: Icons.notes_rounded,
                hint: 'plan_note_hint'.tr,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (widget.item != null) ...[
                    Expanded(
                      child: SecondaryButton(
                        label: 'delete'.tr,
                        danger: true,
                        onPressed: () async {
                          final id = widget.item!.id;
                          Get.back();
                          await widget.c.deleteItem(id);
                          final ctx = Get.context;
                          if (ctx != null) {
                            ScaffoldMessenger.of(ctx)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                SnackBar(
                                  content: Text('deleted'.tr),
                                  action: SnackBarAction(
                                    label: 'undo'.tr,
                                    onPressed: () => widget.c.undoDeleteItem(id),
                                  ),
                                ),
                              );
                          }
                        },
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

/// Nhãn trạng thái thanh toán: Chưa trả / Đặt cọc / Đã trả.
Widget payStatusPill(String status, {int paid = 0, int planned = 0}) {
  return switch (status) {
    PayStatus.paid => StatusPill(
      label: 'pay_paid'.tr,
      color: AppColors.success,
      bg: AppColors.successBg,
    ),
    PayStatus.deposit => StatusPill(
      label: planned > 0
          ? '${'pay_deposit'.tr} ${((paid / planned) * 100).clamp(0, 100).round()}%'
          : 'pay_deposit'.tr,
      color: AppColors.warning,
      bg: AppColors.warningBg,
    ),
    _ => StatusPill(
      label: 'pay_unpaid'.tr,
      color: AppColors.textSecondary,
      bg: const Color(0xFFEDEAF5),
    ),
  };
}

// ------------------------------------------------------------------ khách mời

class _GuestSheet extends StatefulWidget {
  const _GuestSheet(this.c, {this.guest});
  final PlanController c;
  final PlanGuest? guest;

  @override
  State<_GuestSheet> createState() => _GuestSheetState();
}

class _GuestSheetState extends State<_GuestSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.guest?.name ?? '',
  );
  late final TextEditingController _rel = TextEditingController(
    text: widget.guest?.relationship ?? '',
  );
  late final TextEditingController _phone = TextEditingController(
    text: widget.guest?.phone ?? '',
  );
  late final TextEditingController _note = TextEditingController(
    text: widget.guest?.note ?? '',
  );
  late String _side = widget.guest?.side ?? GiftSide.mine;
  late int _party = widget.guest?.partySize ?? 1;
  late String _status = widget.guest?.inviteStatus ?? InviteStatus.planned;
  String? _nameErr;
  int _added = 0;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _rel.dispose();
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<bool> _save({required bool keepOpen}) async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameErr = 'plan_err_name'.tr);
      return false;
    }
    setState(() => _saving = true);
    final base = widget.guest ?? widget.c.newGuest(name: name);
    await widget.c.saveGuest(
      base.copyWith(
        name: name,
        relationship: _rel.text,
        side: _side,
        partySize: _party,
        inviteStatus: _status,
        phone: _phone.text,
        note: _note.text,
      ),
    );
    if (!keepOpen) {
      Get.back();
      return true;
    }
    Toast.show('plan_guest_saved'.trParams({'args1': name}));
    setState(() {
      _added++;
      _name.clear();
      _phone.clear();
      _note.clear();
      _party = 1;
      _status = InviteStatus.planned;
      _saving = false;
    });
    return true;
  }

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(maxHeight: Get.height * 0.9),
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            16,
      ),
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.guest == null ? 'plan_guest_add'.tr : 'plan_guest_edit'.tr,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            if (_added > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: StatusPill(
                  label: 'plan_guest_added_n'.trParams({'args1': '$_added'}),
                  color: AppColors.success,
                  bg: AppColors.successBg,
                ),
              ),
            const SizedBox(height: 8),
            SideSelector(
              value: _side,
              dense: true,
              onChanged: (v) => setState(() => _side = v ?? GiftSide.mine),
            ),
            FieldLabel('plan_guest_name'.tr),
            IconField(
              controller: _name,
              icon: Icons.person_outline_rounded,
              hint: 'hint_guest'.tr,
              errorText: _nameErr,
              onChanged: (_) {
                if (_nameErr != null) setState(() => _nameErr = null);
              },
            ),
            FieldLabel('field_relationship'.tr),
            IconField(
              controller: _rel,
              icon: Icons.diversity_3_rounded,
              hint: 'hint_relationship'.tr,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 8,
                runSpacing: 2,
                children: [
                  for (final r in kRelationshipPresets)
                    ActionChip(
                      label: Text(r),
                      onPressed: () => setState(() => _rel.text = r),
                      backgroundColor: AppColors.chip,
                      side: BorderSide.none,
                      labelStyle: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            FieldLabel('plan_party'.tr),
            Row(
              children: [
                _stepper(Icons.remove_rounded, () {
                  if (_party > 1) setState(() => _party--);
                }),
                SizedBox(
                  width: 70,
                  child: Text(
                    '$_party',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _stepper(Icons.add_rounded, () {
                  if (_party < 50) setState(() => _party++);
                }),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'plan_party_hint'.tr,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
            FieldLabel('plan_invite_status'.tr),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final s in InviteStatus.all)
                  ChoiceChip(
                    label: Text(InviteStatus.labelKey(s).tr),
                    selected: _status == s,
                    onSelected: (_) => setState(() => _status = s),
                    showCheckmark: false,
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.chip,
                    side: BorderSide.none,
                    labelStyle: TextStyle(
                      color: _status == s ? Colors.white : AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
            FieldLabel('plan_phone'.tr),
            IconField(
              controller: _phone,
              icon: Icons.phone_outlined,
              hint: '09xx xxx xxx',
              keyboardType: TextInputType.phone,
            ),
            FieldLabel('plan_note'.tr),
            IconField(
              controller: _note,
              icon: Icons.notes_rounded,
              hint: 'plan_note_hint'.tr,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (widget.guest != null) ...[
                  Expanded(
                    child: SecondaryButton(
                      label: 'delete'.tr,
                      danger: true,
                      onPressed: () async {
                        final id = widget.guest!.id;
                        Get.back();
                        await widget.c.deleteGuest(id);
                        final ctx = Get.context;
                        if (ctx != null) {
                          ScaffoldMessenger.of(ctx)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              SnackBar(
                                content: Text('deleted'.tr),
                                action: SnackBarAction(
                                  label: 'undo'.tr,
                                  onPressed: () => widget.c.undoDeleteGuest(id),
                                ),
                              ),
                            );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                ] else ...[
                  Expanded(
                    child: SecondaryButton(
                      label: 'save'.tr,
                      onPressed: _saving ? null : () => _save(keepOpen: false),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: 2,
                  child: PrimaryButton(
                    label: widget.guest == null
                        ? 'quick_save_next'.tr
                        : 'save'.tr,
                    icon: widget.guest == null ? Icons.add_task_rounded : null,
                    loading: _saving,
                    onPressed: () => _save(keepOpen: widget.guest == null),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget _stepper(IconData i, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.chip,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(i, color: AppColors.primary),
    ),
  );
}

// ----------------------------------------------------------- dán nhiều khách

class _BulkSheet extends StatefulWidget {
  const _BulkSheet(this.c);
  final PlanController c;

  @override
  State<_BulkSheet> createState() => _BulkSheetState();
}

class _BulkSheetState extends State<_BulkSheet> {
  final TextEditingController _text = TextEditingController();
  String _side = GiftSide.mine;
  bool _saving = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  int get _count => parseGuestLines(_text.text).length;

  Future<void> _save() async {
    setState(() => _saving = true);
    final n = await widget.c.addGuestsFromText(_text.text, side: _side);
    Get.back();
    Toast.show(
      n > 0
          ? 'plan_bulk_added'.trParams({'args1': '$n'})
          : 'plan_bulk_none'.tr,
    );
  }

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(maxHeight: Get.height * 0.88),
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'plan_bulk_title'.tr,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'plan_bulk_hint'.tr,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            SideSelector(
              value: _side,
              dense: true,
              onChanged: (v) => setState(() => _side = v ?? GiftSide.mine),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _text,
              minLines: 6,
              maxLines: 10,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(hintText: 'plan_bulk_example'.tr),
            ),
            const SizedBox(height: 14),
            PrimaryButton(
              label: _count == 0
                  ? 'plan_bulk_add'.tr
                  : 'plan_bulk_add_n'.trParams({'args1': '$_count'}),
              loading: _saving,
              onPressed: _count == 0 ? null : _save,
            ),
          ],
        ),
      ),
    ),
  );
}
