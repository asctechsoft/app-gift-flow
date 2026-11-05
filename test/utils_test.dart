import 'package:flutter_test/flutter_test.dart';
import 'package:gift_flow/models/data_models/gift_record.dart';
import 'package:gift_flow/models/ui_models/gift_status.dart';
import 'package:gift_flow/utils/money.dart';
import 'package:gift_flow/utils/text_utils.dart';

void main() {
  test('Money.format groups thousands', () {
    expect(Money.format(186500000), '186.500.000 đ');
    expect(Money.format(0, symbol: false), '0');
  });

  test('Money.parse strips separators', () {
    expect(Money.parse('2.000.000 đ'), 2000000);
    expect(Money.parse('abc'), isNull);
  });

  test('TextUtils.fold removes Vietnamese diacritics', () {
    expect(TextUtils.fold('Nguyễn Văn Hùng'), 'nguyen van hung');
    expect(TextUtils.fold('Đồng nghiệp'), 'dong nghiep');
  });

  test('TextUtils.excelSafe blocks formula injection', () {
    expect(TextUtils.excelSafe('=SUM(A1)'), "'=SUM(A1)");
    expect(TextUtils.excelSafe('Anh Hùng'), 'Anh Hùng');
  });

  test('GiftRecord map round trip keeps status and warnings', () {
    final g = GiftRecord(
      id: 'a',
      eventId: 'e',
      guestName: 'Hùng',
      amountVnd: 2000000,
      status: GiftStatus.pendingReview,
      warnings: const ['possible_duplicate'],
    );
    final r = GiftRecord.fromMap(g.toMap());
    expect(r.status, GiftStatus.pendingReview);
    expect(r.hasDuplicateWarning, isTrue);
    expect(r.isConfirmed, isFalse);
  });
}
