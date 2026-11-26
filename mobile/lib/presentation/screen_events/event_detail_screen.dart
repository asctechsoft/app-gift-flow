import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controller/event_controller.dart';
import '../../controller/gift_controller.dart';
import '../../controller/gift_list_controller.dart';
import '../../controller/settings_controller.dart';
import '../../models/data_models/gift_event.dart';
import '../../models/data_models/gift_record.dart';
import '../../models/ui_models/gift_status.dart';
import '../../repository/gift_filter.dart';
import '../../repository/gift_repository.dart';
import '../../services/application/sync_service.dart';
import '../../utils/date_fmt.dart';
import '../../utils/money.dart';
import '../../values/app_colors.dart';
import '../../values/route_name.dart';
import '../common_components/components.dart';
import '../common_components/ui_kit.dart';
import '../screen_gifts/gift_filter_sheet.dart';
import '../screen_gifts/gifts_tab.dart';
import '../screen_gifts/quick_entry_sheet.dart';
import 'event_actions.dart';

/// Chi tiết sự kiện với 4 tab: Tổng quan · Phong bì · Khách · Thống kê.
class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({super.key});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final EventController events = Get.find<EventController>();
  final GiftRepository repo = Get.find<GiftRepository>();
  final SettingsController settings = Get.find<SettingsController>();
  late final String eventId;
  late final String tag;
  late final GiftListController list;
  int _tab = 0;

  final TextEditingController _search = TextEditingController();
  final TextEditingController _guestSearch = TextEditingController();
  Timer? _debounce;

  List<GuestSummary> _guests = const [];
  List<TrendPoint> _trend = const [];
  int _today = 0;
  Worker? _w1;
  Worker? _w2;

  @override
  void initState() {
    super.initState();
    final args = (Get.arguments as Map?) ?? const {};
    eventId = args['id'] as String? ?? '';
    _tab = (args['tab'] as int?) ?? 0;
    tag = 'event:$eventId';
    list = Get.put(
      GiftListController(
        repo,
        Get.find<GiftController>(),
        events,
        Get.find<SyncService>(),
        eventId: eventId,
      ),
      tag: tag,
    );
    // Mọi thao tác thêm bản ghi (nhập nhanh, giọng nói) sẽ vào sự kiện này.
    events.setActive(eventId);
    _w1 = ever(list.items, (_) => _extras());
    _w2 = ever(events.statsById, (_) => _extras());
    _extras();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _w1?.dispose();
    _w2?.dispose();
    _search.dispose();
    _guestSearch.dispose();
    Get.delete<GiftListController>(tag: tag);
    super.dispose();
  }

  Future<void> _extras() async {
    final now = DateTime.now();
    final g = await repo.guests(eventId, query: _guestSearch.text);
    final t = await repo.trend(eventId);
    final today = await repo.confirmedSince(
      eventId,
      DateTime(now.year, now.month, now.day),
    );
    if (!mounted) return;
    setState(() {
      _guests = g;
      _trend = t;
      _today = today;
    });
  }

  GiftEvent? get _event =>
      events.events.firstWhereOrNull((e) => e.id == eventId);

  @override
  Widget build(BuildContext context) => GradientScaffold(
    body: SafeArea(
      child: Obx(() {
        final e = _event;
        if (e == null) {
          return Column(
            children: [
              _bar(null),
              const Expanded(child: Center(child: CircularProgressIndicator())),
            ],
          );
        }
        return Stack(
          children: [
            Column(
              children: [
                _bar(e),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      4,
                      16,
                      _tab == 0 ? 110 : 40,
                    ),
                    children: [
                      if (_tab == 0) ...[_header(e), const SizedBox(height: 12)],
                      _tabs(),
                      const SizedBox(height: 12),
                      ...switch (_tab) {
                        0 => _overview(e),
                        1 => _envelopes(),
                        2 => _guestTab(),
                        _ => _stats(),
                      },
                    ],
                  ),
                ),
              ],
            ),
            if (_tab == 0)
              Positioned(left: 16, right: 16, bottom: 14, child: _bottomActions(e)),
            if (_tab == 1)
              Positioned(
                right: 18,
                bottom: 22,
                child: AddFab(onTap: showAddMenu),
              ),
            if (_tab == 2)
              Positioned(
                right: 18,
                bottom: 22,
                child: FloatingActionButton.extended(
                  heroTag: 'ev_add_guest',
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  onPressed: () => guardActiveEvent(() => showQuickEntry()),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: Text('guest_add'.tr),
                ),
              ),
          ],
        );
      }),
    ),
  );

  Widget _bar(GiftEvent? e) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
    child: Row(
      children: [
        IconButton(
          tooltip: 'back'.tr,
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: Get.back,
        ),
        Expanded(
          child: Text(
            _tab == 0 ? 'ev_detail_title'.tr : (e?.name ?? ''),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
        if (e != null)
          IconButton(
            tooltip: 'more'.tr,
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () async {
              final deleted = await showEventMenu(events, e, withDetail: false);
              if (deleted) Get.back();
            },
          ),
      ],
    ),
  );

  Widget _header(GiftEvent e) {
    final ph = phaseStyle(e.phaseOn(DateTime.now()));
    return Row(
      children: [
        EventThumb(type: e.type, size: 84),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                e.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              StatusPill(label: ph.label, color: ph.color, bg: ph.bg),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    DateFmt.display(e.eventDate),
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
          child: IconButton(
            tooltip: 'edit'.tr,
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
            onPressed: () => Get.toNamed(RouteName.eventEdit, arguments: {'id': eventId}),
          ),
        ),
      ],
    );
  }

  Widget _tabs() {
    final labels = [
      'tab_overview'.tr,
      'tab_envelopes'.tr,
      'tab_guests'.tr,
      'tab_stats'.tr,
    ];
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == labels.length - 1 ? 0 : 6),
              child: GestureDetector(
                onTap: () => setState(() => _tab = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 10),
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _tab == i ? Colors.white : AppColors.text,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ------------------------------------------------------------ Tổng quan

  List<Widget> _overview(GiftEvent e) {
    final st = events.statsById[eventId] ?? EventStats.empty();
    final avg = st.guests > 0 ? (st.totalVnd / st.guests).round() : 0;
    final pct = st.totalVnd > 0 ? _today / st.totalVnd * 100 : 0.0;
    final expected = settings.expectedFor(eventId);
    final received = st.envelopes + st.pendingCount;
    final progress =
        expected > 0 ? (received / expected).clamp(0.0, 1.0).toDouble() : 0.0;
    return [
      Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 14, 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFA06BF3), Color(0xFF7B3FE4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('home_total'.tr,
                      style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      Money.format(st.totalVnd),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (_today > 0) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '↑ +${Money.format(_today)} (${pct.toStringAsFixed(1).replaceAll('.', ',')}%)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Text('💌', style: TextStyle(fontSize: 52)),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            flex: 9,
            child: StatBox(
              icon: Icons.mail_outline_rounded,
              value: '${st.envelopes}',
              label: 'kpi_envelopes'.tr,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 9,
            child: StatBox(
              icon: Icons.groups_rounded,
              value: '${st.guests}',
              label: 'kpi_guests'.tr,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 14,
            child: StatBox(
              icon: Icons.bar_chart_rounded,
              iconColor: AppColors.warning,
              value: Money.format(avg),
              label: 'kpi_avg'.tr,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      SoftCard(
        onTap: () => _setExpected(expected),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(
              title: 'ev_progress'.tr,
              icon: Icons.flag_outlined,
              trailing: expected > 0 ? null : 'ev_progress_set'.tr,
              onTrailing: () => _setExpected(expected),
            ),
            const SizedBox(height: 10),
            if (expected > 0) ...[
              Text(
                'ev_progress_text'.trParams({
                  'args1': '$received',
                  'args2': '$expected',
                }),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 10,
                        backgroundColor: AppColors.chip,
                        valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${(progress * 100).round()}%',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary),
                  ),
                ],
              ),
            ] else
              Text(
                'ev_progress_hint'.tr,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      SoftCard(
        child: Column(
          children: [
            SectionTitle(
              title: 'ev_recent'.tr,
              icon: Icons.history_rounded,
              trailing: 'see_all'.tr,
              onTrailing: () => setState(() => _tab = 1),
            ),
            const SizedBox(height: 6),
            Obx(() {
              final items = list.items.take(3).toList();
              if (items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    'gifts_empty_title'.tr,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                );
              }
              return Column(
                children: [
                  for (final r in items)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => openGift(r.gift),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(
                          children: [
                            InitialsAvatar(
                              name: r.gift.guestName.isEmpty ? '?' : r.gift.guestName,
                              size: 40,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.gift.guestName.isEmpty
                                        ? 'guest_unknown'.tr
                                        : r.gift.guestName,
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  Text(
                                    _ago(r.gift.createdAt),
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              Money.format(r.gift.amountVnd),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: r.gift.status == GiftStatus.confirmed
                                    ? AppColors.success
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            }),
          ],
        ),
      ),
    ];
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 2) return 'ago_just_now'.tr;
    if (d.inHours < 1) return 'ago_minutes'.trParams({'args1': '${d.inMinutes}'});
    if (d.inDays < 1) return 'ago_hours'.trParams({'args1': '${d.inHours}'});
    return DateFormat('dd/MM/yyyy HH:mm').format(t);
  }

  Future<void> _setExpected(int current) async {
    final ctl = TextEditingController(text: current > 0 ? '$current' : '');
    final n = await Get.dialog<int>(
      AlertDialog(
        title: Text('ev_progress_set_title'.tr),
        content: TextField(
          controller: ctl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: 'ev_progress_set_hint'.tr),
        ),
        actions: [
          TextButton(onPressed: Get.back, child: Text('cancel'.tr)),
          TextButton(
            onPressed: () => Get.back(result: int.tryParse(ctl.text.trim()) ?? 0),
            child: Text('save'.tr),
          ),
        ],
      ),
    );
    if (n == null) return;
    await settings.setExpected(eventId, n);
    if (mounted) setState(() {});
  }

  Widget _bottomActions(GiftEvent e) => Row(
    children: [
      Expanded(
        child: GestureDetector(
          onTap: () => guardActiveEvent(() => showQuickEntry()),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary, width: 1.4),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.bolt_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 6),
                Text(
                  'quick_title'.tr,
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: GestureDetector(
          onTap: () => guardActiveEvent(() => Get.toNamed(RouteName.recording)),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.mic_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 6),
                Text(
                  'ev_voice_btn'.tr,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );

  // -------------------------------------------------------------- Phong bì

  List<Widget> _envelopes() => [
    Row(
      children: [
        Expanded(
          child: TextField(
            controller: _search,
            onChanged: (q) {
              _debounce?.cancel();
              _debounce = Timer(
                const Duration(milliseconds: 250),
                () => list.setQuery(q),
              );
              setState(() {});
            },
            decoration: InputDecoration(
              hintText: 'ev_search_hint'.tr,
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () {
                        _search.clear();
                        list.setQuery('');
                        setState(() {});
                      },
                    ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Obx(() {
          final n = list.filter.value.sheetActiveCount;
          return GestureDetector(
            onTap: () => showGiftFilterSheet(list),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: n > 0 ? AppColors.chip : AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: n > 0 ? AppColors.primary : AppColors.border),
              ),
              child: Badge(
                isLabelVisible: n > 0,
                label: Text('$n'),
                child: const Icon(Icons.tune_rounded, color: AppColors.primary),
              ),
            ),
          );
        }),
      ],
    ),
    const SizedBox(height: 12),
    Obx(
      () => Row(
        children: [
          Expanded(
            child: Text(
              '${list.envelopeCount} ${'kpi_envelopes'.tr.toLowerCase()}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            '${'sum_total'.tr}: ',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          Text(
            Money.format(list.totalVnd),
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 8),
    Obx(() {
      final items = list.items.toList();
      if (items.isEmpty) {
        return SizedBox(
          height: 240,
          child: EmptyState(
            icon: Icons.inbox_outlined,
            title: list.filter.value.hasAny
                ? 'gifts_no_result'.tr
                : 'gifts_empty_title'.tr,
            message: list.filter.value.hasAny ? null : 'gifts_empty_msg'.tr,
          ),
        );
      }
      return Column(
        children: [for (final r in items) _envelopeRow(r.gift)],
      );
    }),
  ];

  Widget _envelopeRow(GiftRecord g) {
    final pending = g.status != GiftStatus.confirmed;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => openGift(g),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.chip,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.mail_outline_rounded, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      g.guestName.isEmpty ? 'guest_unknown'.tr : g.guestName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('HH:mm - dd/MM/yyyy').format(g.createdAt),
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Money.format(g.amountVnd),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: pending ? AppColors.textSecondary : AppColors.success,
                    ),
                  ),
                  if (pending)
                    StatusPill(
                      label: g.status == GiftStatus.failed
                          ? 'status_failed'.tr
                          : 'status_pending'.tr,
                      color: g.status == GiftStatus.failed
                          ? AppColors.danger
                          : AppColors.warning,
                      bg: g.status == GiftStatus.failed
                          ? AppColors.dangerBg
                          : AppColors.warningBg,
                    ),
                ],
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ Khách

  List<Widget> _guestTab() => [
    Row(
      children: [
        Expanded(
          child: TextField(
            controller: _guestSearch,
            onChanged: (_) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 250), _extras);
              setState(() {});
            },
            decoration: InputDecoration(
              hintText: 'guest_search_hint'.tr,
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => setState(() => _tab = 1),
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.tune_rounded, color: AppColors.primary),
          ),
        ),
      ],
    ),
    const SizedBox(height: 12),
    Text(
      '${_guests.length} ${'kpi_guests'.tr.toLowerCase()}',
      style: const TextStyle(fontWeight: FontWeight.w700),
    ),
    const SizedBox(height: 8),
    if (_guests.isEmpty)
      SizedBox(
        height: 220,
        child: EmptyState(
          icon: Icons.groups_outlined,
          title: 'guest_empty'.tr,
        ),
      ),
    for (final g in _guests)
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GestureDetector(
          onTap: () {
            _search.text = g.name;
            list.setQuery(g.name);
            setState(() => _tab = 1);
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
            ),
            child: Row(
              children: [
                InitialsAvatar(name: g.name, size: 44),
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
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if ((g.relationship ?? '').isNotEmpty)
                            StatusPill(
                              label: g.relationship!,
                              color: AppColors.primary,
                              bg: AppColors.chip,
                            ),
                          if (g.count > 1) ...[
                            const SizedBox(width: 6),
                            Text(
                              '${g.count} ${'kpi_envelopes'.tr.toLowerCase()}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  Money.format(g.totalVnd),
                  style: const TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
  ];

  // ---------------------------------------------------------------- Thống kê

  List<Widget> _stats() {
    final st = events.statsById[eventId] ?? EventStats.empty();
    final rels = st.byRelationship.where((r) => r.count > 0).toList();
    final totalCount = rels.fold<int>(0, (a, b) => a + b.count);
    final top = _guests.where((g) => g.totalVnd > 0).take(3).toList();
    const medals = ['🥇', '🥈', '🥉'];
    return [
      SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('stats_overview'.tr,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _mini('🪙', Money.format(st.totalVnd), 'stats_total_money'.tr)),
                const SizedBox(width: 8),
                Expanded(child: _mini('👥', '${st.guests}', 'kpi_guests'.tr)),
                const SizedBox(width: 8),
                Expanded(child: _mini('✉️', '${st.envelopes}', 'kpi_envelopes'.tr)),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('stats_distribution'.tr,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 12),
            if (totalCount == 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('stats_empty'.tr,
                    style: const TextStyle(color: AppColors.textSecondary)),
              )
            else
              Row(
                children: [
                  DonutChart(
                    values: rels.map((r) => r.count.toDouble()).toList(),
                    centerTop: '${st.guests}',
                    centerBottom: 'kpi_guests'.tr,
                    size: 118,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      children: [
                        for (var i = 0; i < rels.length && i < 6; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
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
                                    rels[i].label.isEmpty ? 'rel_none'.tr : rels[i].label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                Text(
                                  '${rels[i].count} (${(rels[i].count / totalCount * 100).round()}%)',
                                  style: const TextStyle(
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
      ),
      const SizedBox(height: 12),
      SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('stats_trend'.tr,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 12),
            if (_trend.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('stats_empty'.tr,
                    style: const TextStyle(color: AppColors.textSecondary)),
              )
            else
              TrendChart(points: _trend),
          ],
        ),
      ),
      const SizedBox(height: 12),
      SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('top_givers_full'.tr,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 8),
            if (top.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('stats_empty'.tr,
                    style: const TextStyle(color: AppColors.textSecondary)),
              ),
            for (var i = 0; i < top.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Text(medals[i], style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        top[i].name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      Money.format(top[i].totalVnd),
                      style: const TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      SecondaryButton(
        label: 'set_export'.tr,
        icon: Icons.file_download_outlined,
        onPressed: () => Get.toNamed(RouteName.export),
      ),
    ];
  }

  Widget _mini(String emoji, String v, String l) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
    decoration: BoxDecoration(
      color: AppColors.chip.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(v, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        ),
        Text(
          l,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
      ],
    ),
  );
}
