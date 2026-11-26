import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controller/invitation_controller.dart';
import '../../models/data_models/invitation.dart';
import '../../utils/date_fmt.dart';
import '../../utils/money.dart';
import '../../values/app_colors.dart';
import '../common_components/components.dart';
import '../common_components/ui_kit.dart';
import 'invitation_sheet.dart';

/// Lịch đi mừng: các đám cưới/sự kiện của người khác mình được mời - ngày giờ, địa điểm,
/// dự chi và đã mừng bao nhiêu cho từng người.
class InvitationsScreen extends StatelessWidget {
  const InvitationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<InvitationController>();
    return GradientScaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _bar(),
                Expanded(child: Obx(() => _body(c))),
              ],
            ),
            Positioned(
              right: 18,
              bottom: 22,
              child: AddFab(onTap: () => showInvitationSheet(c)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bar() => Padding(
    padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
    child: Row(
      children: [
        IconButton(
          tooltip: 'back'.tr,
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: Get.back,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'inv_title'.tr,
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
              ),
              Text(
                'inv_subtitle'.tr,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _body(InvitationController c) {
    final s = c.stats.value;
    final list = c.visible;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 110),
      children: [
        _nextCard(c, s),
        const SizedBox(height: 12),
        _analysis(s),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final f in const ['upcoming', 'attended', 'skipped', 'all'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _chip(c, f),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (!c.loaded.value)
          const Padding(
            padding: EdgeInsets.all(30),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (list.isEmpty)
          SizedBox(
            height: 260,
            child: EmptyState(
              icon: Icons.event_available_outlined,
              title: 'inv_empty'.tr,
              message: 'inv_empty_msg'.tr,
              actionLabel: 'inv_add'.tr,
              onAction: () => showInvitationSheet(c),
            ),
          )
        else
          ..._grouped(c, list),
      ],
    );
  }

  Widget _chip(InvitationController c, String f) {
    final sel = c.filter.value == f;
    final label = switch (f) {
      'upcoming' => 'invt_upcoming'.tr,
      'attended' => 'invt_attended'.tr,
      'skipped' => 'invt_skipped'.tr,
      _ => 'filter_all'.tr,
    };
    return GestureDetector(
      onTap: () => c.filter.value = f,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: sel ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: sel ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          '$label (${c.count(f)})',
          style: TextStyle(
            color: sel ? Colors.white : AppColors.text,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------- sắp tới gần nhất

  Widget _nextCard(InvitationController c, InvitationStats s) {
    final n = s.next;
    if (n == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFA06BF3), Color(0xFF7B3FE4)],
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            const Text('🎊', style: TextStyle(fontSize: 38)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'inv_no_upcoming'.tr,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      );
    }
    final days = n.daysUntil(DateTime.now()) ?? 0;
    return GestureDetector(
      onTap: () => showInvitationSheet(c, item: n),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFA06BF3), Color(0xFF7B3FE4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.25),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 74,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    days == 0 ? '🎉' : '$days',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    days == 0 ? 'inv_today'.tr : 'inv_days_unit'.tr,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'inv_next'.tr,
                    style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                  ),
                  Text(
                    n.personName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${DateFmt.display(n.eventDate)}${n.eventTime == null ? '' : ' · ${n.eventTime}'}',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  if ((n.location ?? '').isNotEmpty)
                    Text(
                      n.location!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                    ),
                  if (n.plannedVnd > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${'invp_planned'.tr}: ${Money.format(n.plannedVnd)}',
                        style: const TextStyle(
                          color: Color(0xFFB8FFD9),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
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

  // --------------------------------------------------------------- phân tích

  Widget _analysis(InvitationStats s) {
    final months = s.byMonth.entries.take(6).toList();
    final maxV = months.isEmpty ? 1 : months.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title: 'inv_analysis'.tr, icon: Icons.insights_rounded),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _kpi(
                  Icons.event_note_outlined,
                  '${s.upcomingCount}',
                  'inv_kpi_upcoming'.tr,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _kpi(
                  Icons.account_balance_wallet_outlined,
                  Money.format(s.upcomingPlannedVnd),
                  'inv_kpi_planned'.tr,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _kpi(
                  Icons.calendar_month_outlined,
                  Money.format(s.next30PlannedVnd),
                  '${'inv_kpi_30d'.tr} (${s.next30Count})',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _kpi(
                  Icons.check_circle_outline_rounded,
                  Money.format(s.givenTotalVnd),
                  '${'inv_kpi_given'.tr} (${s.attendedCount})',
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          if (s.attendedCount > 0) ...[
            const SizedBox(height: 8),
            Text(
              '${'inv_kpi_avg'.tr}: ${Money.format(s.averageGivenVnd)}',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
            ),
          ],
          if (months.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'inv_by_month'.tr,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
            ),
            const SizedBox(height: 8),
            for (final m in months)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 52,
                      child: Text(
                        '${m.key.substring(5)}/${m.key.substring(2, 4)}',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: maxV == 0 ? 0 : m.value / maxV,
                          minHeight: 10,
                          backgroundColor: AppColors.chip,
                          valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 92,
                      child: Text(
                        Money.format(m.value),
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _kpi(IconData i, String v, String l, {Color color = AppColors.primary}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.chip.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(i, color: color, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      v,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l,
                      maxLines: 1,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  // --------------------------------------------------------------- danh sách

  List<Widget> _grouped(InvitationController c, List<Invitation> list) {
    final out = <Widget>[];
    String? month;
    for (final i in list) {
      final m = i.eventDate.length >= 7 ? i.eventDate.substring(0, 7) : '';
      if (m != month) {
        month = m;
        out.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_outlined, size: 18, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  m.length == 7 ? '${'inv_month'.tr} ${m.substring(5)}/${m.substring(0, 4)}' : '',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        );
      }
      out.add(_card(c, i));
      out.add(const SizedBox(height: 8));
    }
    return out;
  }

  Widget _card(InvitationController c, Invitation i) {
    final days = i.daysUntil(DateTime.now());
    final occ = EventTypeInfo.of(i.occasion);
    final (pillText, pillColor, pillBg) = switch (i.status) {
      InviteState.attended => ('invt_attended'.tr, AppColors.success, AppColors.successBg),
      InviteState.skipped => ('invt_skipped'.tr, AppColors.textSecondary, AppColors.chip),
      _ => days == null
          ? ('', AppColors.primary, AppColors.chip)
          : days < 0
              ? ('inv_overdue'.tr, AppColors.danger, AppColors.dangerBg)
              : days == 0
                  ? ('inv_today'.tr, AppColors.warning, AppColors.warningBg)
                  : ('inv_days_left'.trParams({'args1': '$days'}), AppColors.primary, AppColors.chip),
    };
    return GestureDetector(
      onTap: () => showInvitationSheet(c, item: i),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.chip, borderRadius: BorderRadius.circular(14)),
              child: Text(occ.emoji, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          i.personName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                      ),
                      if ((i.relationship ?? '').isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '· ${i.relationship}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${DateFmt.display(i.eventDate)}${i.eventTime == null ? '' : ' · ${i.eventTime}'}',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                  ),
                  if ((i.location ?? '').isNotEmpty)
                    Text(
                      i.location!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (pillText.isNotEmpty)
                        StatusPill(label: pillText, color: pillColor, bg: pillBg),
                      if (i.status == InviteState.attended)
                        Text(
                          '${'inv_given'.tr}: ${Money.format(i.givenVnd)}',
                          style: TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        )
                      else if (i.plannedVnd > 0)
                        Text(
                          '${'invp_planned'.tr}: ${Money.format(i.plannedVnd)}',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (i.isUpcoming)
              IconButton(
                tooltip: 'inv_mark_given'.tr,
                icon: Icon(Icons.check_circle_outline_rounded, color: AppColors.success),
                onPressed: () => showInvitationSheet(c, item: i, markGiven: true),
              )
            else
              const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
