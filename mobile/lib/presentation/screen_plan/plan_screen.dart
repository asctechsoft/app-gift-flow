import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controller/event_controller.dart';
import '../../controller/plan_controller.dart';
import '../../models/data_models/plan_models.dart';
import '../../models/ui_models/gift_status.dart';
import '../../utils/date_fmt.dart';
import '../../utils/money.dart';
import '../../utils/toast_utils.dart';
import '../../values/app_colors.dart';
import '../common_components/components.dart';
import '../common_components/ui_kit.dart';
import 'plan_sheets.dart';

/// Kế hoạch sự kiện (trước lễ): ngân sách theo danh mục + danh sách khách mời dự kiến.
/// Hoàn toàn tách khỏi tiền mừng.
class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  final PlanController c = Get.find<PlanController>();
  final EventController events = Get.find<EventController>();
  late final String eventId;
  int _tab = 0;
  final TextEditingController _search = TextEditingController();
  final Set<String> _collapsed = {};

  @override
  void initState() {
    super.initState();
    final args = (Get.arguments as Map?) ?? const {};
    eventId = args['id'] as String? ?? events.active.value?.id ?? '';
    _tab = (args['tab'] as int?) ?? 0;
    WidgetsBinding.instance.addPostFrameCallback((_) => c.open(eventId));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String get _eventName =>
      events.events.firstWhereOrNull((e) => e.id == eventId)?.name ?? '';

  // ---------------------------------------------------------------- menu

  Future<void> _menu() async {
    Widget tile(IconData i, String t, String v) => ListTile(
      leading: Icon(i, color: AppColors.primary),
      title: Text(t),
      onTap: () => Get.back(result: v),
    );
    final v = await Get.bottomSheet<String>(
      SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            tile(Icons.account_balance_wallet_outlined, 'plan_menu_budget'.tr, 'budget'),
            tile(Icons.auto_awesome_rounded, 'plan_menu_template'.tr, 'template'),
            tile(Icons.playlist_add_rounded, 'plan_menu_bulk'.tr, 'bulk'),
            const SizedBox(height: 8),
          ],
        ),
      ),
      backgroundColor: AppColors.surface,
    );
    switch (v) {
      case 'budget':
        await showBudgetDialog(c);
      case 'template':
        await _template();
      case 'bulk':
        setState(() => _tab = 1);
        await showPlanBulkGuestSheet(c);
    }
  }

  Future<void> _template() async {
    final n = await c.applyWeddingTemplate();
    Toast.show(
      n > 0 ? 'plan_template_added'.trParams({'args1': '$n'}) : 'plan_template_none'.tr,
    );
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) => GradientScaffold(
    body: SafeArea(
      child: Stack(
        children: [
          Column(
            children: [
              _bar(),
              _tabs(),
              const SizedBox(height: 8),
              Expanded(
                child: Obx(() => _tab == 0 ? _budgetTab() : _guestTab()),
              ),
            ],
          ),
          Positioned(
            right: 18,
            bottom: 22,
            child: AddFab(
              onTap: () => _tab == 0
                  ? showPlanItemSheet(c)
                  : showPlanGuestSheet(c),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _bar() => Padding(
    padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
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
                'plan_title'.tr,
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
              ),
              Obx(() {
                events.events.length;
                return Text(
                  _eventName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                  ),
                );
              }),
            ],
          ),
        ),
        IconButton(
          tooltip: 'more'.tr,
          icon: const Icon(Icons.more_vert_rounded),
          onPressed: _menu,
        ),
      ],
    ),
  );

  Widget _tabs() {
    final labels = ['plan_tab_budget'.tr, 'plan_tab_guests'.tr];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i == 0 ? 8 : 0),
                child: GestureDetector(
                  onTap: () => setState(() => _tab = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: _tab == i ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: _tab == i ? AppColors.primary : AppColors.border,
                      ),
                    ),
                    child: Text(
                      labels[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _tab == i ? Colors.white : AppColors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------- ngân sách

  Widget _budgetTab() {
    final s = c.summary.value;
    final items = c.items.toList();
    final cats = [
      for (final cat in PlanCategory.all)
        if (items.any((i) => i.category == cat.key)) cat,
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
      children: [
        _budgetCard(s),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 10,
              child: StatBox(
                icon: Icons.receipt_long_outlined,
                value: Money.format(s.plannedVnd),
                label: 'plan_planned_total'.tr,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 10,
              child: StatBox(
                icon: Icons.task_alt_rounded,
                iconColor: AppColors.success,
                value: Money.format(s.paidVnd),
                label: 'plan_paid_total'.tr,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        StatBox(
          icon: Icons.hourglass_bottom_rounded,
          iconColor: AppColors.warning,
          value: Money.format(s.remainingToPayVnd),
          label: 'plan_remaining'.tr,
        ),
        const SizedBox(height: 14),
        if (items.isEmpty)
          SoftCard(
            child: Column(
              children: [
                const Text('📝', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 6),
                Text(
                  'plan_empty_title'.tr,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'plan_empty_msg'.tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 14),
                PrimaryButton(
                  label: 'plan_menu_template'.tr,
                  icon: Icons.auto_awesome_rounded,
                  onPressed: _template,
                ),
                const SizedBox(height: 8),
                SecondaryButton(
                  label: 'plan_item_add'.tr,
                  icon: Icons.add_rounded,
                  onPressed: () => showPlanItemSheet(c),
                ),
              ],
            ),
          )
        else ...[
          if (s.byCategory.isNotEmpty) _distribution(s),
          const SizedBox(height: 12),
          for (final cat in cats) ...[
            _categoryCard(cat, items.where((i) => i.category == cat.key).toList()),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }

  Widget _budgetCard(PlanSummary s) {
    final budget = s.budgetVnd;
    final ratio = s.budgetUsedRatio;
    final over = s.overBudget;
    return GestureDetector(
      onTap: () => showBudgetDialog(c),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFA06BF3), Color(0xFF7B3FE4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.25),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'plan_budget_total'.tr,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(Icons.edit_outlined, color: Colors.white70, size: 18),
              ],
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                budget == null ? 'plan_budget_unset'.tr : Money.format(budget),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (budget != null && ratio != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: ratio.clamp(0.0, 1.0).toDouble(),
                  minHeight: 10,
                  backgroundColor: Colors.white24,
                  valueColor: AlwaysStoppedAnimation(
                    over ? const Color(0xFFFF8A9A) : Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'plan_budget_used'.trParams({
                  'args1': Money.format(s.plannedVnd),
                  'args2': '${(ratio * 100).round()}',
                }),
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  over
                      ? 'plan_over'.trParams({'args1': Money.format(-(s.budgetLeftVnd ?? 0))})
                      : 'plan_left'.trParams({'args1': Money.format(s.budgetLeftVnd ?? 0)}),
                  style: TextStyle(
                    color: over ? const Color(0xFFFFD0D6) : const Color(0xFFB8FFD9),
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ] else
              Text(
                'plan_budget_set_hint'.tr,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
          ],
        ),
      ),
    );
  }

  Widget _distribution(PlanSummary s) {
    final top = s.byCategory.where((e) => e.plannedVnd > 0).toList();
    if (top.isEmpty) return const SizedBox.shrink();
    final total = top.fold<int>(0, (a, b) => a + b.plannedVnd);
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title: 'plan_by_category'.tr, icon: Icons.pie_chart_outline_rounded),
          const SizedBox(height: 12),
          Row(
            children: [
              DonutChart(
                values: top.map((e) => e.plannedVnd.toDouble()).toList(),
                centerTop: '${top.length}',
                centerBottom: 'plan_categories'.tr,
                size: 112,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  children: [
                    for (var i = 0; i < top.length && i < 6; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: AppColors.chart[i % AppColors.chart.length],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                PlanCategory.of(top[i].category).labelKey.tr,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12.5),
                              ),
                            ),
                            Text(
                              '${(top[i].plannedVnd / total * 100).round()}%',
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
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _categoryCard(PlanCategory cat, List<PlanItem> list) {
    final planned = list.fold<int>(0, (a, i) => a + i.plannedVnd);
    final paid = list.fold<int>(0, (a, i) => a + i.paidVnd);
    final ratio = planned > 0 ? (paid / planned).clamp(0.0, 1.0).toDouble() : 0.0;
    final open = !_collapsed.contains(cat.key);
    return SoftCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => setState(() {
              open ? _collapsed.add(cat.key) : _collapsed.remove(cat.key);
            }),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.chip,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(cat.emoji, style: const TextStyle(fontSize: 21)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cat.labelKey.tr,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              '${list.length} ${'plan_items_n'.tr}',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            Money.format(planned),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${'pay_paid'.tr} ${Money.format(paid)}',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                      Icon(
                        open
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 6,
                      backgroundColor: AppColors.chip,
                      valueColor: AlwaysStoppedAnimation(
                        ratio >= 1 ? AppColors.success : AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (open) ...[
            Divider(height: 1, color: AppColors.border.withValues(alpha: 0.7)),
            for (final i in list) _itemRow(i),
            InkWell(
              onTap: () => showPlanItemSheet(c, category: cat.key),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_rounded, size: 18, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      'plan_item_add_here'.tr,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _itemRow(PlanItem i) {
    final sub = <String>[
      if ((i.vendor ?? '').isNotEmpty) i.vendor!,
      if ((i.dueDate ?? '').isNotEmpty) '${'plan_due_short'.tr} ${DateFmt.display(i.dueDate!)}',
    ].join(' · ');
    return InkWell(
      onTap: () => showPlanItemSheet(c, item: i),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    i.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (sub.isNotEmpty)
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  i.plannedVnd > 0 ? Money.format(i.plannedVnd) : 'plan_unpriced'.tr,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: i.plannedVnd > 0 ? AppColors.text : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                payStatusPill(i.status, paid: i.paidVnd, planned: i.plannedVnd),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------- khách

  Widget _guestTab() {
    final s = c.summary.value;
    final list = c.guests.toList();
    final filtered = c.guestSide.value != null ||
        c.guestStatus.value != null ||
        c.guestQuery.value.isNotEmpty;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
      children: [
        _guestSummary(s),
        const SizedBox(height: 12),
        TextField(
          controller: _search,
          onChanged: (q) {
            c.guestQuery.value = q;
            setState(() {});
          },
          decoration: InputDecoration(
            hintText: 'guest_search_hint'.tr,
            prefixIcon: Icon(Icons.search_rounded, color: AppColors.textSecondary),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () {
                      _search.clear();
                      c.guestQuery.value = '';
                      setState(() {});
                    },
                  ),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _chip(
                '${'filter_all'.tr} (${s.guestCount})',
                c.guestStatus.value == null,
                () => c.guestStatus.value = null,
              ),
              for (final st in InviteStatus.all)
                _chip(
                  '${InviteStatus.labelKey(st).tr} (${s.byStatus[st] ?? 0})',
                  c.guestStatus.value == st,
                  () => c.guestStatus.value = c.guestStatus.value == st ? null : st,
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _chip('filter_all'.tr, c.guestSide.value == null, () => c.guestSide.value = null,
                        icon: Icons.groups_outlined),
                    _chip(GiftSide.labelKey(GiftSide.mine).tr, c.guestSide.value == GiftSide.mine,
                        () => c.guestSide.value = GiftSide.mine),
                    _chip(GiftSide.labelKey(GiftSide.parents).tr, c.guestSide.value == GiftSide.parents,
                        () => c.guestSide.value = GiftSide.parents),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: 'plan_menu_bulk'.tr,
              icon: const Icon(Icons.playlist_add_rounded, color: AppColors.primary),
              onPressed: () => showPlanBulkGuestSheet(c),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (list.isEmpty)
          SizedBox(
            height: 260,
            child: EmptyState(
              icon: Icons.groups_outlined,
              title: filtered ? 'gifts_no_result'.tr : 'plan_guest_empty'.tr,
              message: filtered ? null : 'plan_guest_empty_msg'.tr,
              actionLabel: filtered ? null : 'plan_guest_add'.tr,
              onAction: filtered ? null : () => showPlanGuestSheet(c),
            ),
          ),
        for (final g in list) ...[
          _guestRow(g),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _guestSummary(PlanSummary s) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFFEFE4FF), Color(0xFFE2D2FC)]),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        _gs('${s.guestCount}', 'plan_gs_guests'.tr),
        _gdiv(),
        _gs('${s.headcountExpected}', 'plan_gs_people'.tr),
        _gdiv(),
        _gs('${s.byStatus[InviteStatus.confirmed] ?? 0}', 'plan_gs_confirmed'.tr),
        _gdiv(),
        _gs('${s.byStatus[InviteStatus.planned] ?? 0}', 'plan_gs_todo'.tr),
      ],
    ),
  );

  Widget _gs(String v, String l) => Expanded(
    child: Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(v, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(l, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ),
      ],
    ),
  );

  Widget _gdiv() => Container(
    width: 1,
    height: 32,
    color: AppColors.primary.withValues(alpha: 0.2),
  );

  Widget _chip(String label, bool selected, VoidCallback onTap, {IconData? icon}) =>
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selected ? AppColors.primary : AppColors.border),
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 15, color: selected ? Colors.white : AppColors.primary),
                  const SizedBox(width: 5),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _guestRow(PlanGuest g) {
    final st = switch (g.inviteStatus) {
      InviteStatus.confirmed => (AppColors.success, AppColors.successBg),
      InviteStatus.invited => (const Color(0xFF3A6FE0), const Color(0xFFE3EDFF)),
      InviteStatus.declined => (AppColors.danger, AppColors.dangerBg),
      _ => (AppColors.textSecondary, const Color(0xFFEDEAF5)),
    };
    return GestureDetector(
      onTap: () => showPlanGuestSheet(c, guest: g),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
        ),
        child: Row(
          children: [
            InitialsAvatar(name: g.name, size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    g.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if ((g.relationship ?? '').isNotEmpty) g.relationship!,
                      '${g.partySize} ${'plan_people'.tr}',
                      if (g.side == GiftSide.parents) GiftSide.labelKey(g.side).tr,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _statusMenu(g),
              child: StatusPill(
                label: InviteStatus.labelKey(g.inviteStatus).tr,
                color: st.$1,
                bg: st.$2,
              ),
            ),
            IconButton(
              tooltip: 'more'.tr,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.more_vert_rounded, size: 20),
              onPressed: () => _guestMenu(g),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _statusMenu(PlanGuest g) async {
    final v = await Get.bottomSheet<String>(
      SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  g.name,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            for (final s in InviteStatus.all)
              ListTile(
                title: Text(InviteStatus.labelKey(s).tr),
                trailing: g.inviteStatus == s
                    ? const Icon(Icons.check_rounded, color: AppColors.primary)
                    : null,
                onTap: () => Get.back(result: s),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
      backgroundColor: AppColors.surface,
    );
    if (v != null) await c.setInviteStatus(g, v);
  }

  Future<void> _guestMenu(PlanGuest g) async {
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
            ListTile(
              leading: const Icon(Icons.swap_horiz_rounded, color: AppColors.primary),
              title: Text('plan_change_status'.tr),
              onTap: () => Get.back(result: 'status'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: AppColors.danger),
              title: Text('delete'.tr, style: TextStyle(color: AppColors.danger)),
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
        await showPlanGuestSheet(c, guest: g);
      case 'status':
        await _statusMenu(g);
      case 'delete':
        await c.deleteGuest(g.id);
        final ctx = Get.context;
        if (ctx != null) {
          ScaffoldMessenger.of(ctx)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text('deleted'.tr),
                action: SnackBarAction(
                  label: 'undo'.tr,
                  onPressed: () => c.undoDeleteGuest(g.id),
                ),
              ),
            );
        }
    }
  }
}
