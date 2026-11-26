import 'package:flutter_test/flutter_test.dart';
import 'package:gift_flow/controller/plan_controller.dart';
import 'package:gift_flow/models/data_models/plan_models.dart';

void main() {
  group('PayStatus.derive', () {
    test('chưa trả / đặt cọc / đã trả', () {
      expect(PayStatus.derive(100, 0), PayStatus.planned);
      expect(PayStatus.derive(100, 30), PayStatus.deposit);
      expect(PayStatus.derive(100, 100), PayStatus.paid);
      expect(PayStatus.derive(100, 120), PayStatus.paid); // trả vượt vẫn là đã trả
    });
    test('chưa có giá dự kiến mà đã trả -> đặt cọc, không coi là đã trả', () {
      expect(PayStatus.derive(0, 50), PayStatus.deposit);
    });
  });

  group('PlanSummary.compute', () {
    PlanItem item(String cat, int planned, int paid) => PlanItem(
      id: '$cat$planned',
      eventId: 'e',
      category: cat,
      name: 'x',
      plannedVnd: planned,
      paidVnd: paid,
    );
    PlanGuest guest(String st, int party, {String side = 'mine'}) => PlanGuest(
      id: '$st$party$side',
      eventId: 'e',
      name: 'n',
      partySize: party,
      inviteStatus: st,
      side: side,
    );

    test('tổng, còn phải trả, theo danh mục (giảm dần), vượt ngân sách', () {
      final s = PlanSummary.compute(
        budgetVnd: 100,
        items: [item('venue', 80, 30), item('catering', 50, 0), item('venue', 10, 10)],
        guests: const [],
      );
      expect(s.plannedVnd, 140);
      expect(s.paidVnd, 40);
      expect(s.remainingToPayVnd, 100);
      expect(s.overBudget, isTrue);
      expect(s.budgetLeftVnd, -40);
      expect(s.byCategory.first.category, 'venue');
      expect(s.byCategory.first.plannedVnd, 90);
      expect(s.byCategory.first.count, 2);
    });

    test('chưa đặt ngân sách -> không có tỉ lệ, không bị coi là vượt', () {
      final s = PlanSummary.compute(budgetVnd: null, items: [item('venue', 10, 0)], guests: const []);
      expect(s.budgetUsedRatio, isNull);
      expect(s.overBudget, isFalse);
      expect(s.budgetLeftVnd, isNull);
    });

    test('khách: số khách, số người (bỏ khách từ chối), theo trạng thái', () {
      final s = PlanSummary.compute(
        budgetVnd: null,
        items: const [],
        guests: [
          guest(InviteStatus.confirmed, 2),
          guest(InviteStatus.invited, 1),
          guest(InviteStatus.declined, 4),
          guest(InviteStatus.planned, 3, side: 'parents'),
        ],
      );
      expect(s.guestCount, 4);
      expect(s.headcount, 10);
      expect(s.headcountExpected, 6);
      expect(s.byStatus[InviteStatus.declined], 1);
    });
  });

  group('parseGuestLines', () {
    test('tên - quan hệ - số người, dấu phẩy, gạch đầu dòng, đánh số', () {
      final l = parseGuestLines(
        'Anh Long - Bạn thân - 2\n'
        '- Cô Lan, đồng nghiệp\n'
        '1. Bác Hùng\n'
        '\n'
        '  Em Mai ; Gia đình ; 3 người  \n',
      );
      expect(l.map((e) => e.name), ['Anh Long', 'Cô Lan', 'Bác Hùng', 'Em Mai']);
      expect(l[0].relationship, 'Bạn thân');
      expect(l[0].partySize, 2);
      expect(l[1].relationship, 'đồng nghiệp');
      expect(l[1].partySize, 1);
      expect(l[2].relationship, isNull);
      expect(l[3].partySize, 3);
    });

    test('số người ngoài khoảng được kẹp 1..50; dòng trống bị bỏ', () {
      final l = parseGuestLines('A - 999\n\n   \nB - 0');
      expect(l.length, 2);
      expect(l[0].partySize, 50);
      expect(l[1].partySize, 1);
    });
  });

  group('Chuyển đổi dữ liệu', () {
    test('PlanItem: map + API round trip giữ đủ trường', () {
      final i = PlanItem(
        id: 'a',
        eventId: 'e',
        category: 'photo',
        name: 'Chụp ảnh',
        plannedVnd: 15000000,
        paidVnd: 5000000,
        status: PayStatus.deposit,
        vendor: 'Studio A',
        dueDate: '2026-04-01',
        note: 'ghi chú',
      );
      final back = PlanItem.fromMap(i.toMap());
      expect(back.name, 'Chụp ảnh');
      expect(back.plannedVnd, 15000000);
      expect(back.dueDate, '2026-04-01');
      final api = i.toApi();
      expect(api['planned_vnd'], 15000000);
      expect(api['event_id'], 'e');
      expect(api.containsKey('id'), isFalse); // id nằm ở URL
    });

    test('PlanGuest: map/API; trạng thái lạ -> chưa mời', () {
      final g = PlanGuest(
        id: 'g',
        eventId: 'e',
        name: 'Anh Long',
        relationship: 'Bạn',
        side: 'parents',
        partySize: 3,
        inviteStatus: InviteStatus.confirmed,
      );
      final back = PlanGuest.fromMap(g.toMap());
      expect(back.partySize, 3);
      expect(back.side, 'parents');
      expect(g.toApi()['invite_status'], 'confirmed');
      expect(InviteStatus.normalize('weird'), InviteStatus.planned);
      expect(g.toMap()['search_key'], contains('anh long')); // không dấu để tìm kiếm
    });

    test('PlanItem.fromApi đọc đúng phản hồi backend', () {
      final i = PlanItem.fromApi({
        'id': 'x',
        'event_id': 'e',
        'category': 'venue',
        'name': 'Nhà hàng',
        'planned_vnd': 100000000,
        'paid_vnd': 0,
        'status': 'planned',
        'vendor': null,
        'due_date': null,
        'note': null,
        'created_at': '2026-05-01T00:00:00.000Z',
        'updated_at': '2026-05-01T00:00:00.000Z',
        'deleted_at': null,
      });
      expect(i.plannedVnd, 100000000);
      expect(i.synced, isTrue);
      expect(i.remainingVnd, 100000000);
    });
  });
}
