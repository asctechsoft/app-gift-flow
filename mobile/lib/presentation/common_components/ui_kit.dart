import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/data_models/gift_event.dart';
import '../../repository/gift_filter.dart';
import '../../values/app_colors.dart';

/// Loại sự kiện: nhãn, biểu tượng (emoji) và màu nền ảnh bìa.
class EventTypeInfo {
  const EventTypeInfo(this.type, this.labelKey, this.emoji, this.c1, this.c2);
  final String type;
  final String labelKey;
  final String emoji;
  final Color c1;
  final Color c2;

  static const wedding = EventTypeInfo(
    'wedding', 'etype_wedding', '💍', Color(0xFFF7E3C8), Color(0xFFE9B97F));
  static const engagement = EventTypeInfo(
    'engagement', 'etype_engagement', '💐', Color(0xFFFBD9E4), Color(0xFFF2A3BE));
  static const birthday = EventTypeInfo(
    'birthday', 'etype_birthday', '🎂', Color(0xFFFFE0F0), Color(0xFFFFB4D6));
  static const housewarming = EventTypeInfo(
    'housewarming', 'etype_housewarming', '🏠', Color(0xFFD9F0E4), Color(0xFF9BD8B8));
  static const babyMonth = EventTypeInfo(
    'baby_month', 'etype_baby', '👶', Color(0xFFDDE8FF), Color(0xFFA9C2F7));
  static const other = EventTypeInfo(
    'other', 'etype_other', '🎁', Color(0xFFEADCFF), Color(0xFFC9A8F7));

  /// Thứ tự hiển thị trong bộ lọc / form tạo sự kiện.
  static const List<EventTypeInfo> all = [
    wedding, engagement, birthday, housewarming, babyMonth, other,
  ];

  static EventTypeInfo of(String? type) => all.firstWhere(
    (e) => e.type == type,
    orElse: () => other,
  );
}

/// Ảnh bìa vuông bo góc của sự kiện (gradient + emoji theo loại).
class EventThumb extends StatelessWidget {
  const EventThumb({super.key, required this.type, this.size = 64});
  final String type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = EventTypeInfo.of(type);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.26),
        gradient: LinearGradient(
          colors: [t.c1, t.c2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: t.c2.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(t.emoji, style: TextStyle(fontSize: size * 0.5)),
    );
  }
}

/// Hình minh hoạ góc phải tiêu đề màn hình (cụm emoji trên nền tròn mờ).
class HeaderBadge extends StatelessWidget {
  const HeaderBadge({super.key, required this.main, this.sub = const []});
  final String main;
  final List<String> sub;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 96,
    height: 84,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                AppColors.accent.withValues(alpha: 0.35),
                AppColors.primary.withValues(alpha: 0.12),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Text(main, style: const TextStyle(fontSize: 42)),
        for (var i = 0; i < sub.length && i < 3; i++)
          Positioned(
            top: i == 0 ? 0 : (i == 1 ? 6 : null),
            bottom: i == 2 ? 2 : null,
            right: i == 0 ? 2 : (i == 1 ? null : 6),
            left: i == 1 ? 4 : null,
            child: Text(sub[i], style: const TextStyle(fontSize: 16)),
          ),
      ],
    ),
  );
}

/// Avatar chữ cái đầu, màu ổn định theo tên.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.name, this.size = 42});
  final String name;
  final double size;

  static const _palette = [
    (Color(0xFFE8F4EC), Color(0xFF188B54)),
    (Color(0xFFEDE5FF), Color(0xFF7837E8)),
    (Color(0xFFFFE6EE), Color(0xFFD6457A)),
    (Color(0xFFE3EDFF), Color(0xFF3A6FE0)),
    (Color(0xFFFFF0D9), Color(0xFFC77D12)),
    (Color(0xFFDFF5F3), Color(0xFF17958A)),
  ];

  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    final l = parts.toList();
    if (l.length == 1) return l.first.characters.first.toUpperCase();
    return (l[l.length - 2].characters.first + l.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final c = _palette[name.hashCode.abs() % _palette.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.$1, shape: BoxShape.circle),
      child: Text(
        initials(name),
        style: TextStyle(
          color: c.$2,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.34,
        ),
      ),
    );
  }
}

/// Tiêu đề mục: [icon] Tiêu đề ........ [trailing]
class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    this.icon,
    this.trailing,
    this.onTrailing,
  });
  final String title;
  final IconData? icon;
  final String? trailing;
  final VoidCallback? onTrailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (icon != null) ...[
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
      ],
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      if (trailing != null)
        GestureDetector(
          onTap: onTrailing,
          child: Text(
            trailing!,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
    ],
  );
}

/// Ô thống kê nhỏ: biểu tượng + số lớn + nhãn.
class StatBox extends StatelessWidget {
  const StatBox({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.iconColor = AppColors.primary,
  });
  final IconData icon;
  final String value;
  final String label;
  final Color iconColor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.05),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: 7),
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
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// "20M", "500K", "1,2M" cho nhãn trục biểu đồ.
String moneyShort(num v) {
  if (v >= 1000000000) return '${_trim(v / 1000000000)}B';
  if (v >= 1000000) return '${_trim(v / 1000000)}M';
  if (v >= 1000) return '${_trim(v / 1000)}K';
  return v.toStringAsFixed(0);
}

String _trim(double d) {
  final s = d.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s.replaceAll('.', ',');
}

/// Nhãn trạng thái sự kiện (Đang diễn ra / Sắp diễn ra / Đã kết thúc).
({String label, Color color, Color bg}) phaseStyle(EventPhase p) =>
    switch (p) {
      EventPhase.ongoing => (
        label: 'phase_ongoing'.tr,
        color: AppColors.success,
        bg: AppColors.successBg,
      ),
      EventPhase.upcoming => (
        label: 'phase_upcoming'.tr,
        color: const Color(0xFF3A6FE0),
        bg: const Color(0xFFE3EDFF),
      ),
      EventPhase.ended => (
        label: 'phase_ended'.tr,
        color: AppColors.textSecondary,
        bg: const Color(0xFFEDEAF5),
      ),
    };

/// Biểu đồ tròn rỗng giữa, chữ ở giữa.
class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.values,
    required this.centerTop,
    required this.centerBottom,
    this.size = 120,
  });
  final List<double> values;
  final String centerTop;
  final String centerBottom;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        CustomPaint(size: Size.square(size), painter: _Donut(values)),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              centerTop,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            Text(
              centerBottom,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _Donut extends CustomPainter {
  _Donut(this.values);
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (a, b) => a + b);
    const stroke = 20.0;
    final r = (Offset.zero & size).deflate(stroke / 2);
    canvas.drawArc(
      r,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = AppColors.chip,
    );
    if (total <= 0) return;
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * math.pi * 2;
      canvas.drawArc(
        r,
        start,
        math.max(0.0, sweep - (values.length > 1 ? 0.05 : 0.0)),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.butt
          ..color = AppColors.chart[i % AppColors.chart.length],
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _Donut old) => old.values != values;
}

/// Đường xu hướng tiền mừng cộng dồn theo ngày (có vùng tô mờ + trục).
class TrendChart extends StatelessWidget {
  const TrendChart({super.key, required this.points, this.height = 150});
  final List<TrendPoint> points;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: CustomPaint(painter: _Trend(points)),
  );
}

class _Trend extends CustomPainter {
  _Trend(this.points);
  final List<TrendPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 34.0;
    const bottom = 20.0;
    final chart = Rect.fromLTWH(left, 6, size.width - left - 6, size.height - bottom - 6);
    final maxV = points.isEmpty
        ? 1
        : points.map((p) => p.cumulativeVnd).reduce(math.max).clamp(1, 1 << 62);
    // lưới ngang + nhãn trục tung (4 mức)
    final grid = Paint()
      ..color = AppColors.border.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = chart.bottom - chart.height * i / 3;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), grid);
      _text(canvas, moneyShort(maxV * i / 3), Offset(0, y - 7), 10);
    }
    if (points.isEmpty) return;
    Offset pt(int i) {
      final x = points.length == 1
          ? chart.center.dx
          : chart.left + chart.width * i / (points.length - 1);
      final y = chart.bottom - chart.height * points[i].cumulativeVnd / maxV;
      return Offset(x, y);
    }

    final line = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < points.length; i++) {
      final a = pt(i - 1);
      final b = pt(i);
      final mid = (a.dx + b.dx) / 2;
      line.cubicTo(mid, a.dy, mid, b.dy, b.dx, b.dy);
    }
    final fill = Path.from(line)
      ..lineTo(pt(points.length - 1).dx, chart.bottom)
      ..lineTo(pt(0).dx, chart.bottom)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.28),
            AppColors.primary.withValues(alpha: 0.02),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(chart),
    );
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..color = AppColors.primary,
    );
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(pt(i), 3.5, Paint()..color = AppColors.primary);
      canvas.drawCircle(pt(i), 1.6, Paint()..color = Colors.white);
    }
    // nhãn ngày: đầu, giữa, cuối
    final idx = <int>{0, points.length ~/ 2, points.length - 1}.toList()..sort();
    for (final i in idx) {
      final d = points[i].day;
      final label = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
      _text(canvas, label, Offset(pt(i).dx - 14, chart.bottom + 4), 10);
    }
  }

  void _text(Canvas c, String s, Offset o, double size) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(color: AppColors.textSecondary, fontSize: size),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, o);
  }

  @override
  bool shouldRepaint(covariant _Trend old) => old.points != points;
}

/// Nhãn nhỏ "AI" cạnh tính năng dùng AI.
class AiBadge extends StatelessWidget {
  const AiBadge({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      gradient: AppColors.primaryGradient,
      borderRadius: BorderRadius.circular(6),
    ),
    child: const Text(
      'AI',
      style: TextStyle(
        color: Colors.white,
        fontSize: 9,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

/// Nút "+" tròn nổi (tự vẽ để không bị viền mặc định của FAB).
class AddFab extends StatelessWidget {
  const AddFab({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.primaryGradient,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
      ),
    ),
  );
}
