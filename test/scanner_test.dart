import 'package:flutter_test/flutter_test.dart';
import 'package:gift_flow/models/data_models/gift_record.dart';
import 'package:gift_flow/models/ui_models/gift_status.dart';
import 'package:gift_flow/services/application/envelope_scanner.dart';

void main() {
  test('OCR phong bì: lấy dòng tên và số tiền rõ ràng', () {
    final r = EnvelopeScanner.parse('Anh Nguyễn Văn Hùng\n500.000đ\n0912345678');
    expect(r.lines.first, 'Anh Nguyễn Văn Hùng');
    expect(r.amountVnd, 500000);
  });

  test('OCR: số nhỏ/ngày tháng không bị nhận nhầm là tiền', () {
    final r = EnvelopeScanner.parse('Chị Lan\n24/05/2025');
    expect(r.amountVnd, isNull);
  });

  test('OCR: 2tr và 500k', () {
    expect(EnvelopeScanner.parse('Bác Tư 2tr').amountVnd, 2000000);
    expect(EnvelopeScanner.parse('Cô Hoa 500k').amountVnd, 500000);
  });

  test('GiftRecord giữ nhóm khách qua map', () {
    final g = GiftRecord(id: 'a', eventId: 'e', side: GiftSide.parents);
    expect(GiftRecord.fromMap(g.toMap()).side, GiftSide.parents);
    expect(GiftRecord.fromMap(g.toMap()).toApi()['side'], 'parents');
  });
}
