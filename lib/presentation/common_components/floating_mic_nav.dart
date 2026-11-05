import 'package:asc_common/asc_common.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../values/app_colors.dart';

/// Bottom nav 5 vị trí: [Trang chủ] [Sự kiện] [MIC nổi] [Danh sách] [Cá nhân].
/// Mic là hành động mở màn ghi âm, không phải tab.
class FloatingMicNav extends StatelessWidget {
  const FloatingMicNav({
    super.key,
    required this.index,
    required this.onTab,
    required this.onMic,
  });

  /// 0 Trang chủ, 1 Sự kiện, 2 Danh sách, 3 Cá nhân.
  final int index;
  final ValueChanged<int> onTab;
  final VoidCallback onMic;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return SizedBox(
      height: 72 + bottom + 14,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            height: 64 + bottom,
            padding: EdgeInsets.only(bottom: bottom),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                _item(0, Icons.home_rounded, 'nav_home'.tr),
                _item(1, Icons.event_note_rounded, 'nav_events'.tr),
                const Expanded(child: SizedBox()), // chỗ của mic
                _item(2, Icons.format_list_bulleted_rounded, 'nav_list'.tr),
                _item(3, Icons.person_rounded, 'nav_me'.tr),
              ],
            ),
          ),
          Positioned(
            bottom: 20 + bottom,
            child: Semantics(
              button: true,
              label: 'nav_mic'.tr,
              child: AppTouchable(
                onTap: onMic,
                borderRadius: BorderRadius.circular(40),
                pressedScale: 0.92,
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.mic_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(int i, IconData icon, String label) {
    final sel = index == i;
    final color = sel ? AppColors.primary : AppColors.textSecondary;
    return Expanded(
      child: InkResponse(
        onTap: () => onTab(i),
        radius: 40,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
