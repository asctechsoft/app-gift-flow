import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../configs/app_config.dart';
import '../../controller/gift_controller.dart';
import '../../models/ui_models/gift_status.dart';
import '../../services/application/envelope_scanner.dart';
import '../../utils/money.dart';
import '../../utils/toast_utils.dart';
import '../../values/app_colors.dart';
import '../common_components/components.dart';
import '../common_components/dialogs.dart';
import '../common_components/money_input_formatter.dart';

/// Nhập nhanh: tên + chip số tiền + nhóm + quan hệ, "Lưu & thêm tiếp" - không cần mở mic.
Future<void> showQuickEntry({String? initialSide, ImageSource? scanSource}) =>
    Get.bottomSheet(
      QuickEntrySheet(initialSide: initialSide, scanSource: scanSource),
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    );

class QuickEntrySheet extends StatefulWidget {
  const QuickEntrySheet({super.key, this.initialSide, this.scanSource});
  final String? initialSide;

  /// Mở sheet là quét luôn (camera hoặc thư viện ảnh).
  final ImageSource? scanSource;

  @override
  State<QuickEntrySheet> createState() => _QuickEntrySheetState();
}

class _QuickEntrySheetState extends State<QuickEntrySheet> {
  static const _amounts = [100000, 200000, 500000, 1000000, 2000000, 5000000];
  static String _lastSide = GiftSide.mine;
  static String? _lastRel;

  final GiftController _c = Get.find<GiftController>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _amount = TextEditingController();
  final FocusNode _nameFocus = FocusNode();
  late String _side = widget.initialSide ?? _lastSide;
  String? _rel = _lastRel;
  List<String> _scanLines = const [];
  bool _scanning = false;
  bool _saving = false;
  String? _nameErr;
  String? _amountErr;
  int _savedCount = 0;
  int _savedTotal = 0;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  String _short(int v) => v >= 1000000 ? '${v ~/ 1000000}tr' : '${v ~/ 1000}k';

  void _pickAmount(int v) {
    setState(() {
      _amount.text = Money.format(v, symbol: false);
      _amountErr = null;
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.scanSource != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scan(source: widget.scanSource!),
      );
    }
  }

  Future<void> _scan({ImageSource source = ImageSource.camera}) async {
    setState(() => _scanning = true);
    try {
      final r = await EnvelopeScanner().scan(source: source);
      if (r == null) return;
      if (r.lines.isEmpty && r.amountVnd == null) {
        Toast.show('scan_none'.tr);
        return;
      }
      setState(() {
        _scanLines = r.lines.take(6).toList();
        if (r.amountVnd != null) _pickAmount(r.amountVnd!);
        if (_name.text.isEmpty && _scanLines.isNotEmpty) {
          _name.text = _scanLines.first;
        }
      });
    } catch (_) {
      Toast.show('scan_failed'.tr);
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<bool> _save({required bool keepOpen}) async {
    final name = _name.text.trim();
    final amount = Money.parse(_amount.text);
    setState(() {
      _nameErr = name.isEmpty ? 'err_name'.tr : null;
      _amountErr = (amount == null || amount <= 0)
          ? 'err_amount'.tr
          : (amount > AppConfig.maxAmountVnd ? 'err_amount_max'.tr : null);
    });
    if (_nameErr != null || _amountErr != null) return false;
    setState(() => _saving = true);
    try {
      final dups = await _c.duplicatesOf(name, amount!);
      if (dups.isNotEmpty) {
        final keep = await confirmDialog(
          title: 'dup_title'.tr,
          message: 'dup_msg'.tr,
          confirmLabel: 'dup_keep'.tr,
        );
        if (!keep) return false;
      }
      await _c.addManual(
        name: name,
        amount: amount,
        relationship: _rel,
        side: _side,
        warnings: dups.isNotEmpty ? const ['possible_duplicate'] : const [],
      );
      _lastSide = _side;
      _lastRel = _rel;
      _savedCount++;
      _savedTotal += amount;
      if (keepOpen) {
        setState(() {
          _name.clear();
          _amount.clear();
          _scanLines = const [];
        });
        _nameFocus.requestFocus();
      } else {
        Get.back();
        Toast.show('saved'.tr);
      }
      return true;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
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
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'quick_title'.tr,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _scanning ? null : _scan,
                      icon: _scanning
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.document_scanner_outlined),
                      label: Text('scan_envelope'.tr),
                    ),
                  ],
                ),
                if (_savedCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: StatusPill(
                      label: 'quick_session'.trParams({
                        'args1': '$_savedCount',
                        'args2': Money.format(_savedTotal),
                      }),
                      color: AppColors.success,
                      bg: AppColors.successBg,
                    ),
                  ),
                SideSelector(
                  value: _side,
                  dense: true,
                  onChanged: (v) => setState(() => _side = v ?? GiftSide.mine),
                ),
                FieldLabel('field_guest'.tr),
                IconField(
                  controller: _name,
                  focusNode: _nameFocus,
                  icon: Icons.person_outline_rounded,
                  hint: 'hint_guest'.tr,
                  errorText: _nameErr,
                  onChanged: (_) {
                    if (_nameErr != null) setState(() => _nameErr = null);
                  },
                ),
                if (_scanLines.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'scan_pick_name'.tr,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final l in _scanLines)
                        ActionChip(
                          label: Text(l, overflow: TextOverflow.ellipsis),
                          onPressed: () => setState(() => _name.text = l),
                          backgroundColor: AppColors.warningBg,
                          side: BorderSide.none,
                        ),
                    ],
                  ),
                ],
                FieldLabel('field_amount'.tr),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final a in _amounts)
                      ChoiceChip(
                        label: Text(_short(a)),
                        selected: Money.parse(_amount.text) == a,
                        onSelected: (_) => _pickAmount(a),
                        showCheckmark: false,
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.chip,
                        side: BorderSide.none,
                        labelStyle: TextStyle(
                          color: Money.parse(_amount.text) == a
                              ? Colors.white
                              : AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                IconField(
                  controller: _amount,
                  icon: Icons.payments_outlined,
                  hint: 'quick_amount_other'.tr,
                  keyboardType: TextInputType.number,
                  inputFormatters: [MoneyInputFormatter()],
                  errorText: _amountErr,
                  onChanged: (_) => setState(() => _amountErr = null),
                  suffix: const Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: Center(
                      widthFactor: 1,
                      child: Text('đ',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
                FieldLabel('field_relationship'.tr),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final r in kRelationshipPresets)
                      ChoiceChip(
                        label: Text(r),
                        selected: _rel == r,
                        onSelected: (s) => setState(() => _rel = s ? r : null),
                        showCheckmark: false,
                        selectedColor: AppColors.accent,
                        backgroundColor: AppColors.chip,
                        side: BorderSide.none,
                        labelStyle: TextStyle(
                          color: _rel == r ? Colors.white : AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: SecondaryButton(
                        label: 'save'.tr,
                        onPressed:
                            _saving ? null : () => _save(keepOpen: false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: PrimaryButton(
                        label: 'quick_save_next'.tr,
                        icon: Icons.add_task_rounded,
                        loading: _saving,
                        onPressed: () => _save(keepOpen: true),
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
