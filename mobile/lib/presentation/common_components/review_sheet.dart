import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/data_models/gift_record.dart';
import '../../models/ui_models/gift_status.dart';
import '../../utils/money.dart';
import '../../values/app_colors.dart';
import 'components.dart';
import 'money_input_formatter.dart';

/// X03 - duyệt bản ghi AI chưa chắc chắn / nghi trùng trước khi tính vào tổng.
Future<void> showReviewSheet(
  GiftRecord g, {
  required Future<void> Function(String name, int amount, String? rel)
      onConfirm,
  required Future<void> Function() onDelete,
  Future<void> Function()? onRetry,
}) {
  return Get.bottomSheet(
    _ReviewSheet(
      gift: g,
      onConfirm: onConfirm,
      onDelete: onDelete,
      onRetry: onRetry,
    ),
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
  );
}

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({
    required this.gift,
    required this.onConfirm,
    required this.onDelete,
    this.onRetry,
  });
  final GiftRecord gift;
  final Future<void> Function(String, int, String?) onConfirm;
  final Future<void> Function() onDelete;
  final Future<void> Function()? onRetry;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.gift.guestName,
  );
  late final TextEditingController _amount = TextEditingController(
    text: widget.gift.amountVnd > 0
        ? Money.format(widget.gift.amountVnd, symbol: false)
        : '',
  );
  late final TextEditingController _rel = TextEditingController(
    text: widget.gift.relationship ?? '',
  );
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _rel.dispose();
    super.dispose();
  }

  List<String> get _reasons {
    final g = widget.gift;
    final r = <String>[];
    if (g.status == GiftStatus.failed) {
      return [g.errorMessage ?? 'err_generic'.tr];
    }
    if (g.hasDuplicateWarning) r.add('warn_duplicate'.tr);
    if (g.guestName.trim().isEmpty) r.add('warn_name_missing'.tr);
    if (g.amountVnd <= 0 || g.warnings.contains('amount_unclear')) {
      r.add('warn_amount_unclear'.tr);
    }
    if (r.isEmpty) r.add('warn_needs_review'.tr);
    return r;
  }

  Future<void> _confirm() async {
    final amount = Money.parse(_amount.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'err_amount'.tr);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    await widget.onConfirm(_name.text, amount, _rel.text);
    if (mounted) Get.back();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.gift;
    final failed = g.status == GiftStatus.failed;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
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
              const SizedBox(height: 14),
              Text(
                failed ? 'review_failed_title'.tr : 'review_title'.tr,
                style:
                    const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              for (final r in _reasons)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: ErrorBanner(
                    message: r,
                    warning: !failed,
                    icon: failed
                        ? Icons.error_outline_rounded
                        : Icons.warning_amber_rounded,
                  ),
                ),
              if ((g.transcript ?? '').isNotEmpty) ...[
                FieldLabel('review_transcript'.tr),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.chip,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '"${g.transcript}"',
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                ),
              ],
              ...[
                FieldLabel('field_guest'.tr),
                IconField(
                  controller: _name,
                  icon: Icons.person_outline_rounded,
                  hint: 'hint_guest'.tr,
                ),
                FieldLabel('field_amount'.tr),
                IconField(
                  controller: _amount,
                  icon: Icons.payments_outlined,
                  keyboardType: TextInputType.number,
                  inputFormatters: [MoneyInputFormatter()],
                  errorText: _error,
                  hint: '0',
                ),
                FieldLabel('field_relationship'.tr),
                IconField(
                  controller: _rel,
                  icon: Icons.diversity_3_rounded,
                  hint: 'hint_relationship'.tr,
                ),
              ],
              const SizedBox(height: 20),
              if (failed && widget.onRetry != null) ...[
                PrimaryButton(
                  label: 'retry'.tr,
                  icon: Icons.refresh_rounded,
                  onPressed: () async {
                    await widget.onRetry!();
                    if (mounted) Get.back();
                  },
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      label: g.hasDuplicateWarning
                          ? 'review_undo'.tr
                          : 'delete'.tr,
                      danger: true,
                      onPressed: _busy
                          ? null
                          : () async {
                              await widget.onDelete();
                              if (mounted) Get.back();
                            },
                    ),
                  ),
                  ...[
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: PrimaryButton(
                        label: g.hasDuplicateWarning
                            ? 'review_keep'.tr
                            : 'confirm'.tr,
                        loading: _busy,
                        onPressed: _confirm,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
