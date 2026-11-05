import 'package:asc_common/asc_common.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../models/data_models/gift_event.dart';
import '../../models/data_models/gift_record.dart';
import '../../models/ui_models/gift_status.dart';
import '../../utils/date_fmt.dart';
import '../../utils/money.dart';
import '../../values/app_colors.dart';

/// Nền gradient tím pastel dùng chung cho các màn.
class GradientScaffold extends StatelessWidget {
  const GradientScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottom,
    this.floatingActionButton,
    this.resizeToAvoidBottomInset = true,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottom;
  final Widget? floatingActionButton;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(gradient: AppColors.screenGradient),
    child: Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: appBar,
      body: body,
      bottomNavigationBar: bottom,
      floatingActionButton: floatingActionButton,
    ),
  );
}

/// Header có nút quay lại (các màn chức năng).
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppHeader({super.key, required this.title, this.actions});
  final String title;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
    leading: IconButton(
      tooltip: 'back'.tr,
      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
      onPressed: () => Get.back(),
    ),
    title: Text(title),
    actions: actions,
  );
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        decoration: BoxDecoration(
          gradient: color == null ? AppColors.primaryGradient : null,
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (color ?? AppColors.primary).withValues(alpha: 0.28),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: AppTouchable(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                else ...[
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.danger = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool danger;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = danger ? AppColors.danger : AppColors.primary;
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: danger ? AppColors.danger : AppColors.border),
      ),
      child: AppTouchable(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: c, size: 20),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: c,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thẻ trắng bo tròn nền cho nhóm nội dung.
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.margin,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return card;
    return AppTouchable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: card,
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => SoftCard(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    child: Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 28),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class EventCard extends StatelessWidget {
  const EventCard({
    super.key,
    required this.event,
    required this.totalVnd,
    this.selected = false,
    this.onTap,
    this.onMore,
    this.compact = false,
  });

  final GiftEvent event;
  final int? totalVnd;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onMore;
  final bool compact;

  @override
  Widget build(BuildContext context) => AppTouchable(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.border,
          width: selected ? 1.6 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        event.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusPill(
                      label: event.isClosed
                          ? 'event_closed'.tr
                          : (selected ? 'event_active'.tr : 'event_open'.tr),
                      color: event.isClosed
                          ? AppColors.textSecondary
                          : AppColors.success,
                      bg: event.isClosed ? AppColors.chip : AppColors.successBg,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  DateFmt.display(event.eventDate) +
                      ((event.location ?? '').isEmpty
                          ? ''
                          : ' · ${event.location}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                if (totalVnd != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    Money.format(totalVnd!),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onMore != null)
            IconButton(
              tooltip: 'more'.tr,
              onPressed: onMore,
              icon: const Icon(Icons.more_vert_rounded),
            )
          else
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
        ],
      ),
    ),
  );
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    required this.bg,
  });
  final String label;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
    ),
  );
}

/// Dòng một bản ghi tiền mừng (danh sách + phiên ghi âm).
class GiftRow extends StatelessWidget {
  const GiftRow({
    super.key,
    required this.gift,
    this.onTap,
    this.trailing,
    this.showSync = true,
  });
  final GiftRecord gift;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showSync;

  @override
  Widget build(BuildContext context) {
    final g = gift;
    final unknown = g.guestName.trim().isEmpty;
    final (pillLabel, pillColor, pillBg) = switch (g.status) {
      GiftStatus.processing => (
        'status_processing'.tr,
        AppColors.primary,
        AppColors.chip,
      ),
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
      GiftStatus.confirmed => ('', AppColors.success, AppColors.successBg),
    };
    return AppTouchable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.chip,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    unknown ? 'guest_unknown'.tr : g.guestName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      fontStyle: unknown ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          (g.relationship ?? '').isEmpty
                              ? 'rel_none'.tr
                              : g.relationship!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (showSync && !g.synced && g.status != GiftStatus.processing)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Tooltip(
                            message: 'unsynced'.tr,
                            child: const Icon(
                              Icons.cloud_off_rounded,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (g.status == GiftStatus.processing)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                else
                  Text(
                    g.amountVnd > 0 ? Money.format(g.amountVnd) : '—',
                    style: TextStyle(
                      color: g.status == GiftStatus.confirmed
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                if (pillLabel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  StatusPill(label: pillLabel, color: pillColor, bg: pillBg),
                ],
              ],
            ),
            if (trailing != null) ...[const SizedBox(width: 4), trailing!],
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(
              color: AppColors.chip,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: 18),
            PrimaryButton(label: actionLabel!, onPressed: onAction),
          ],
        ],
      ),
    ),
  );
}

/// Banner lỗi / cảnh báo (X05): mạng, quota, sync.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({
    super.key,
    required this.message,
    this.icon = Icons.wifi_off_rounded,
    this.warning = false,
    this.actionLabel,
    this.onAction,
  });
  final String message;
  final IconData icon;
  final bool warning;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final fg = warning ? AppColors.warning : AppColors.danger;
    final bg = warning ? AppColors.warningBg : AppColors.dangerBg;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 44),
                foregroundColor: fg,
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

/// Khung xương khi đang tải.
class LoadingSkeleton extends StatefulWidget {
  const LoadingSkeleton({super.key, this.height = 72, this.radius = 16});
  final double height;
  final double radius;

  @override
  State<LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) => Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: Color.lerp(AppColors.chip, AppColors.border, _c.value),
        borderRadius: BorderRadius.circular(widget.radius),
      ),
    ),
  );
}

/// Ô nhập có icon (form S08/X02/X01).
class IconField extends StatelessWidget {
  const IconField({
    super.key,
    required this.controller,
    this.hint,
    this.icon,
    this.keyboardType,
    this.maxLines = 1,
    this.onChanged,
    this.readOnly = false,
    this.onTap,
    this.textCapitalization = TextCapitalization.words,
    this.suffix,
    this.errorText,
    this.inputFormatters,
    this.autofocus = false,
    this.focusNode,
  });

  final FocusNode? focusNode;
  final TextEditingController controller;
  final String? hint;
  final IconData? icon;
  final TextInputType? keyboardType;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final VoidCallback? onTap;
  final TextCapitalization textCapitalization;
  final Widget? suffix;
  final String? errorText;
  final List<TextInputFormatter>? inputFormatters;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    focusNode: focusNode,
    keyboardType: keyboardType,
    maxLines: maxLines,
    onChanged: onChanged,
    readOnly: readOnly,
    onTap: onTap,
    autofocus: autofocus,
    textCapitalization: textCapitalization,
    inputFormatters: inputFormatters,
    decoration: InputDecoration(
      hintText: hint,
      errorText: errorText,
      prefixIcon: icon == null
          ? null
          : Icon(icon, color: AppColors.textSecondary),
      suffixIcon: suffix,
    ),
  );
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6, top: 14),
    child: Text(
      text,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
    ),
  );
}

/// Chọn nhóm khách: của mình / của bố mẹ. [allowAll] thêm lựa chọn "Tất cả" (null).
class SideSelector extends StatelessWidget {
  const SideSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.allowAll = false,
    this.dense = false,
  });

  final String? value;
  final ValueChanged<String?> onChanged;
  final bool allowAll;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final opts = <(String?, String, IconData)>[
      if (allowAll) (null, 'filter_all'.tr, Icons.groups_rounded),
      (GiftSide.mine, 'side_mine'.tr, Icons.emoji_people_rounded),
      (GiftSide.parents, 'side_parents'.tr, Icons.family_restroom_rounded),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.chip,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final o in opts)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(o.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  constraints: BoxConstraints(minHeight: dense ? 40 : 46),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value == o.$1 ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        o.$3,
                        size: 18,
                        color: value == o.$1 ? Colors.white : AppColors.primary,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          o.$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: value == o.$1
                                ? Colors.white
                                : AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
