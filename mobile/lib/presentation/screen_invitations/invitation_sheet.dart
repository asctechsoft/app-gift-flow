import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controller/invitation_controller.dart';
import '../../models/data_models/invitation.dart';
import '../../utils/date_fmt.dart';
import '../../utils/money.dart';
import '../../values/app_colors.dart';
import '../common_components/components.dart';
import '../common_components/money_input_formatter.dart';
import '../common_components/ui_kit.dart';

/// Thêm / sửa một lời mời. [markGiven]: mở thẳng ở bước "đã mừng" (đánh dấu đã đi).
Future<void> showInvitationSheet(
  InvitationController c, {
  Invitation? item,
  bool markGiven = false,
}) => Get.bottomSheet(
  InvitationSheet(c, item: item, markGiven: markGiven),
  isScrollControlled: true,
  backgroundColor: AppColors.surface,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
);

class InvitationSheet extends StatefulWidget {
  const InvitationSheet(this.c, {this.item, this.markGiven = false});
  final InvitationController c;
  final Invitation? item;
  final bool markGiven;

  @override
  State<InvitationSheet> createState() => _InvitationSheetState();
}

class _InvitationSheetState extends State<InvitationSheet> {
  late final TextEditingController _name = TextEditingController(text: widget.item?.personName ?? '');
  late final TextEditingController _rel = TextEditingController(text: widget.item?.relationship ?? '');
  late final TextEditingController _loc = TextEditingController(text: widget.item?.location ?? '');
  late final TextEditingController _note = TextEditingController(text: widget.item?.note ?? '');
  late final TextEditingController _planned = TextEditingController(
    text: (widget.item?.plannedVnd ?? 0) > 0 ? Money.format(widget.item!.plannedVnd, symbol: false) : '',
  );
  late final TextEditingController _given = TextEditingController(
    text: (widget.item?.givenVnd ?? 0) > 0
        ? Money.format(widget.item!.givenVnd, symbol: false)
        : (widget.markGiven && (widget.item?.plannedVnd ?? 0) > 0
            ? Money.format(widget.item!.plannedVnd, symbol: false)
            : ''),
  );
  late String _occasion = widget.item?.occasion ?? 'wedding';
  late String _status = widget.markGiven ? InviteState.attended : (widget.item?.status ?? InviteState.upcoming);
  late DateTime _date = DateTime.tryParse(widget.item?.eventDate ?? '') ?? DateTime.now().add(const Duration(days: 7));
  TimeOfDay? _time;
  String? _nameErr;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.item?.eventTime;
    if (t != null && RegExp(r'^\d{2}:\d{2}$').hasMatch(t)) {
      _time = TimeOfDay(hour: int.parse(t.substring(0, 2)), minute: int.parse(t.substring(3, 5)));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _rel.dispose();
    _loc.dispose();
    _note.dispose();
    _planned.dispose();
    _given.dispose();
    super.dispose();
  }

  String? get _timeStr => _time == null
      ? null
      : '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 10, minute: 0),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (t != null) setState(() => _time = t);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameErr = 'plan_err_name'.tr);
      return;
    }
    setState(() => _saving = true);
    final planned = Money.parse(_planned.text) ?? 0;
    var given = Money.parse(_given.text) ?? 0;
    // Đánh dấu "đã đi" mà chưa nhập số tiền đã mừng: lấy theo dự chi.
    if (_status == InviteState.attended && given == 0) given = planned;
    final base = widget.item ??
        widget.c.newInvitation(personName: name, eventDate: DateFmt.iso(_date));
    await widget.c.save(
      base.copyWith(
        personName: name,
        relationship: _rel.text,
        occasion: _occasion,
        eventDate: DateFmt.iso(_date),
        eventTime: _timeStr,
        location: _loc.text,
        plannedVnd: planned,
        givenVnd: _status == InviteState.attended ? given : (Money.parse(_given.text) ?? 0),
        status: _status,
        note: _note.text,
      ),
    );
    Get.back();
  }

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(maxHeight: Get.height * 0.92),
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 16,
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
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.item == null ? 'inv_add'.tr : 'inv_edit'.tr,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            FieldLabel('inv_person'.tr),
            IconField(
              controller: _name,
              icon: Icons.favorite_border_rounded,
              hint: 'inv_person_hint'.tr,
              errorText: _nameErr,
              onChanged: (_) {
                if (_nameErr != null) setState(() => _nameErr = null);
              },
            ),
            FieldLabel('field_relationship'.tr),
            IconField(controller: _rel, icon: Icons.diversity_3_rounded, hint: 'hint_relationship'.tr),
            FieldLabel('inv_occasion'.tr),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final t in EventTypeInfo.all)
                  ChoiceChip(
                    avatar: Text(t.emoji),
                    label: Text(t.labelKey.tr),
                    selected: _occasion == t.type,
                    onSelected: (_) => setState(() => _occasion = t.type),
                    showCheckmark: false,
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.chip,
                    side: BorderSide.none,
                    labelStyle: TextStyle(
                      color: _occasion == t.type ? Colors.white : AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
            FieldLabel('inv_when'.tr),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SoftCard(
                    onTap: _pickDate,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: 10),
                        Text(DateFmt.display(DateFmt.iso(_date))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: SoftCard(
                    onTap: _pickTime,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                    child: Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_timeStr ?? 'inv_time_none'.tr)),
                        if (_time != null)
                          GestureDetector(
                            onTap: () => setState(() => _time = null),
                            child: const Icon(Icons.close_rounded, size: 18),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            FieldLabel('inv_location'.tr),
            IconField(controller: _loc, icon: Icons.place_outlined, hint: 'inv_location_hint'.tr),
            FieldLabel('invp_planned'.tr),
            IconField(
              controller: _planned,
              icon: Icons.savings_outlined,
              hint: '0',
              keyboardType: TextInputType.number,
              inputFormatters: [MoneyInputFormatter()],
              suffix: const Padding(
                padding: EdgeInsets.only(right: 16),
                child: Center(widthFactor: 1, child: Text('đ', style: TextStyle(fontWeight: FontWeight.w800))),
              ),
            ),
            FieldLabel('inv_status'.tr),
            Wrap(
              spacing: 8,
              children: [
                for (final s in InviteState.all)
                  ChoiceChip(
                    label: Text(InviteState.labelKey(s).tr),
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
            if (_status == InviteState.attended) ...[
              FieldLabel('inv_given'.tr),
              IconField(
                controller: _given,
                icon: Icons.card_giftcard_rounded,
                hint: 'inv_given_hint'.tr,
                keyboardType: TextInputType.number,
                inputFormatters: [MoneyInputFormatter()],
                suffix: const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: Center(widthFactor: 1, child: Text('đ', style: TextStyle(fontWeight: FontWeight.w800))),
                ),
              ),
            ],
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
                        await widget.c.delete(id);
                        final ctx = Get.context;
                        if (ctx != null) {
                          ScaffoldMessenger.of(ctx)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              SnackBar(
                                content: Text('deleted'.tr),
                                action: SnackBarAction(
                                  label: 'undo'.tr,
                                  onPressed: () => widget.c.undoDelete(id),
                                ),
                              ),
                            );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(flex: 2, child: PrimaryButton(label: 'save'.tr, loading: _saving, onPressed: _save)),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
