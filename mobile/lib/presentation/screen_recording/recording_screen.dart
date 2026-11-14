import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controller/recording_controller.dart';
import '../../models/data_models/gift_record.dart';
import '../../models/ui_models/gift_status.dart';
import '../../utils/money.dart';
import '../../values/app_colors.dart';
import '../../values/route_name.dart';
import '../common_components/components.dart';
import '../common_components/review_sheet.dart';

/// S05 - Ghi âm FULLSCREEN, KHÔNG navbar. Danh sách realtime phía trên,
/// mic/stop cố định phía dưới.
class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  final RecordingController c = Get.find<RecordingController>();

  @override
  void initState() {
    super.initState();
    c.items.clear();
    c.banner.value = null;
    WidgetsBinding.instance.addPostFrameCallback((_) => c.start());
  }

  Future<void> _finish() async {
    await c.stopSession();
    if (c.items.isEmpty) {
      Get.back();
    } else {
      Get.offNamed(RouteName.recordResult);
    }
  }

  Future<void> _close() async {
    await c.stopSession();
    Get.back();
  }

  void _review(GiftRecord g) {
    if (g.status == GiftStatus.confirmed || g.status == GiftStatus.processing) {
      return;
    }
    showReviewSheet(
      g,
      onConfirm: (n, a, r) => c.confirmItem(g, name: n, amount: a, relationship: r),
      onDelete: () => c.undoItem(g),
      onRetry: c.canRetry(g) ? () => c.retry(g) : null,
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _close();
    },
    child: GradientScaffold(
      body: SafeArea(
        child: Obx(() {
          final st = c.state.value;
          if (st == RecState.denied) return _denied();
          if (st == RecState.error && c.event == null) return _noEvent();
          return Column(
            children: [
              _topBar(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Obx(
                  () => SideSelector(
                    value: c.side.value,
                    dense: true,
                    onChanged: (v) => c.side.value = v ?? GiftSide.mine,
                  ),
                ),
              ),
              Obx(() {
                final b = c.banner.value;
                if (b == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: ErrorBanner(message: b),
                );
              }),
              Expanded(child: _list()),
              Obx(() {
                final info = c.sttInfo.value;
                if (info.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                  child: Text(
                    info,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                  ),
                );
              }),
              Obx(() {
                final t = c.liveText.value;
                if (t.isEmpty) return const SizedBox.shrink();
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.chip,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    t,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, height: 1.35),
                  ),
                );
              }),
              _controls(st),
            ],
          );
        }),
      ),
    ),
  );

  Widget _topBar() => Padding(
    padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
    child: Row(
      children: [
        IconButton(
          tooltip: 'close'.tr,
          onPressed: _close,
          icon: const Icon(Icons.close_rounded),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                'rec_title'.tr,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              if (c.event != null)
                Text(
                  c.event!.name,
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
        const SizedBox(width: 48),
      ],
    ),
  );

  Widget _list() => Obx(() {
    final items = c.items.toList();
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Text(
            'rec_empty'.tr,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final g = items[i];
        final undo = g.status == GiftStatus.confirmed;
        return GiftRow(
          gift: g,
          showSync: false,
          showTranscript: true,
          onTap: () => _review(g),
          trailing: undo
              ? IconButton(
                  tooltip: 'undo'.tr,
                  onPressed: () => c.undoItem(g),
                  icon: const Icon(
                    Icons.undo_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                )
              : (g.status == GiftStatus.failed || g.status == GiftStatus.pendingReview)
              ? const Icon(Icons.chevron_right_rounded)
              : null,
        );
      },
    );
  });

  Widget _controls(RecState st) {
    final listening = st == RecState.listening;
    final busy = st == RecState.starting || st == RecState.stopping;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Obx(() {
            final n = c.processingCount;
            final txt = busy
                ? (st == RecState.stopping ? 'rec_finishing'.tr : 'rec_starting'.tr)
                : listening
                ? (c.speaking.value ? 'rec_hearing'.tr : 'rec_listening'.tr)
                : 'rec_paused'.tr;
            return Column(
              children: [
                Text(
                  txt,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  n > 0
                      ? 'rec_processing'.trParams({'args1': '$n'})
                      : 'rec_hint'.tr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Mic: bấm để chốt phong bì hiện tại.
              Obx(() {
                final lv = listening ? c.level.value : 0.0;
                return Semantics(
                  button: true,
                  label: 'rec_cut'.tr,
                  child: GestureDetector(
                    onTap: listening ? c.cutSegment : null,
                    child: SizedBox(
                      width: 128,
                      height: 128,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            width: 96 + 32 * lv,
                            height: 96 + 32 * lv,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.accent.withValues(alpha: 0.22),
                            ),
                          ),
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppColors.primaryGradient,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: busy
                                ? const Padding(
                                    padding: EdgeInsets.all(28),
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 3,
                                    ),
                                  )
                                : const Icon(
                                    Icons.mic_rounded,
                                    color: Colors.white,
                                    size: 44,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(width: 20),
              // Stop: kết thúc phiên.
              Semantics(
                button: true,
                label: 'rec_stop'.tr,
                child: GestureDetector(
                  onTap: busy ? null : _finish,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.danger.withValues(alpha: 0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.stop_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Obx(() {
            final n = c.confirmedCount;
            if (c.items.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'rec_session_sum'.trParams({
                  'args1': '${c.items.length}',
                  'args2': Money.format(c.confirmedTotal),
                  'args3': '$n',
                }),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  /// X04 - từ chối quyền micro.
  Widget _denied() => Column(
    children: [
      _topBar(),
      Expanded(
        child: EmptyState(
          icon: Icons.mic_off_rounded,
          title: 'mic_denied_title'.tr,
          message: 'mic_denied_msg'.tr,
          actionLabel: 'open_settings'.tr,
          onAction: c.openAppSettingsForMic,
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          children: [
            SecondaryButton(
              label: 'try_again'.tr,
              icon: Icons.refresh_rounded,
              onPressed: c.start,
            ),
            const SizedBox(height: 10),
            SecondaryButton(
              label: 'add_manual'.tr,
              icon: Icons.edit_outlined,
              onPressed: () {
                Get.back();
                Get.toNamed(RouteName.giftEdit);
              },
            ),
          ],
        ),
      ),
    ],
  );

  Widget _noEvent() => Column(
    children: [
      _topBar(),
      Expanded(
        child: EmptyState(
          icon: Icons.event_busy_rounded,
          title: 'need_event_first'.tr,
          actionLabel: 'event_create'.tr,
          onAction: () {
            Get.back();
            Get.toNamed(RouteName.eventEdit);
          },
        ),
      ),
    ],
  );
}
