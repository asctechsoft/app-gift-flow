import 'package:flutter_test/flutter_test.dart';
import 'package:gift_flow/models/data_models/invitation.dart';
import 'package:gift_flow/services/application/notification_service.dart';

Invitation inv(
  String id,
  String date, {
  String? time,
  int planned = 0,
  int given = 0,
  String status = InviteState.upcoming,
}) => Invitation(
  id: id,
  personName: 'P$id',
  eventDate: date,
  eventTime: time,
  plannedVnd: planned,
  givenVnd: given,
  status: status,
);

void main() {
  final now = DateTime(2030, 6, 10, 9, 0);

  group('InvitationStats', () {
    test('tổng dự chi, 30 ngày tới, đã mừng, theo tháng, gần nhất', () {
      final list = [
        inv('a', '2030-06-12', time: '10:00', planned: 500000),
        inv('b', '2030-06-30', planned: 1000000),
        inv('c', '2030-08-01', planned: 700000), // ngoài 30 ngày
        inv('d', '2030-05-20', planned: 500000, given: 600000, status: InviteState.attended),
        inv('e', '2030-05-01', planned: 300000, status: InviteState.skipped),
        inv('f', '2030-06-01', planned: 400000), // quá hạn: không tính sắp tới
      ];
      final s = InvitationStats.compute(list, now);
      expect(s.upcomingCount, 3);
      expect(s.upcomingPlannedVnd, 2200000);
      expect(s.next30PlannedVnd, 1500000);
      expect(s.next30Count, 2);
      expect(s.attendedCount, 1);
      expect(s.givenTotalVnd, 600000);
      expect(s.averageGivenVnd, 600000);
      expect(s.next?.id, 'a');
      expect(s.byMonth['2030-06'], 1500000);
      expect(s.byMonth['2030-08'], 700000);
    });

    test('rỗng không lỗi', () {
      final s = InvitationStats.compute(const [], now);
      expect(s.upcomingCount, 0);
      expect(s.next, isNull);
      expect(s.averageGivenVnd, 0);
    });
  });

  group('planReminders', () {
    test('20:00 tối hôm trước + 2 giờ trước giờ diễn ra', () {
      final r = NotificationService.planReminders(
        [inv('a', '2030-06-12', time: '10:00', planned: 500000)],
        now,
      );
      expect(r.length, 2);
      final ats = r.map((e) => e.at).toList()..sort();
      expect(ats[0], DateTime(2030, 6, 11, 20));
      expect(ats[1], DateTime(2030, 6, 12, 8));
    });

    test('không có giờ: nhắc 08:00 ngày diễn ra', () {
      final r = NotificationService.planReminders([inv('a', '2030-06-12')], now);
      expect(r.map((e) => e.at).toList()..sort(), [
        DateTime(2030, 6, 11, 20),
        DateTime(2030, 6, 12, 8),
      ]);
    });

    test('bỏ qua mốc đã qua, lời mời đã đi/bỏ qua và quá hạn', () {
      final r = NotificationService.planReminders([
        inv('a', '2030-06-10', time: '10:00'), // hôm nay 10:00: nhắc 08:00 đã qua, 20:00 hôm trước đã qua
        inv('b', '2030-06-20', status: InviteState.attended),
        inv('c', '2030-06-21', status: InviteState.skipped),
        inv('d', '2030-06-01'),
      ], now);
      expect(r, isEmpty);
    });

    test('id nhắc không trùng nhau giữa các lời mời', () {
      final r = NotificationService.planReminders([
        inv('a', '2030-07-01'),
        inv('b', '2030-07-02'),
      ], now);
      expect(r.map((e) => e.id).toSet().length, 4);
    });
  });
}
