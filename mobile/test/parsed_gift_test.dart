import 'package:flutter_test/flutter_test.dart';
import 'package:gift_flow/models/data_models/parsed_gift.dart';

Map<String, dynamic> resp({
  String? name = 'Anh Long',
  String? rel,
  Object? amount = 2000000,
  bool review = false,
  bool dup = false,
  List<String> warnings = const [],
}) => {
  'request_id': 'r1',
  'transcript': 'Anh Long mừng hai triệu',
  'data': {
    'guest_name': name,
    'relationship': rel,
    'amount': amount,
    'currency': 'VND',
  },
  'needs_review': review,
  'possible_duplicate': dup,
  'warnings': warnings,
};

void main() {
  group('ParsedGift.fromJson', () {
    test('đọc đúng dữ liệu hợp lệ', () {
      final p = ParsedGift.fromJson(resp(rel: 'bạn bố'));
      expect(p.guestName, 'Anh Long');
      expect(p.relationship, 'bạn bố');
      expect(p.amount, 2000000);
      expect(p.needsReview, isFalse);
    });
    test('chuỗi rỗng -> null, số double -> int', () {
      final p = ParsedGift.fromJson(resp(name: '  ', amount: 500000.0));
      expect(p.guestName, isNull);
      expect(p.amount, 500000);
    });
    test('thiếu needs_review -> coi là cần kiểm tra', () {
      final j = resp()..remove('needs_review');
      expect(ParsedGift.fromJson(j).needsReview, isTrue);
    });
    test('JSON rỗng/lạ không crash và không tự tin', () {
      final p = ParsedGift.fromJson({});
      expect(p.amount, isNull);
      expect(p.needsReview, isTrue);
      expect(decideSave(p, autoSaveEnabled: true), SaveDecision.review);
    });
  });

  group('decideSave (business rules)', () {
    SaveDecision d(Map<String, dynamic> j, {bool auto = true}) =>
        decideSave(ParsedGift.fromJson(j), autoSaveEnabled: auto);

    test('"Anh Long mừng hai triệu" rõ ràng -> tự lưu', () {
      expect(d(resp()), SaveDecision.autoSave);
    });
    test('tắt auto-save -> luôn chờ xác nhận', () {
      expect(d(resp(), auto: false), SaveDecision.review);
    });
    test('"Anh Long mừng..." (không có số tiền) -> chờ xác nhận', () {
      expect(
        d(resp(amount: null, review: true, warnings: ['amount_missing'])),
        SaveDecision.review,
      );
    });
    test('thiếu tên -> chờ xác nhận', () {
      expect(d(resp(name: null)), SaveDecision.review);
    });
    test('nghi trùng -> chờ xác nhận, không tự lưu', () {
      expect(
        d(resp(dup: true, warnings: ['possible_duplicate'])),
        SaveDecision.review,
      );
    });
    test('AI đánh dấu needs_review (vd. tên không chắc) -> chờ xác nhận', () {
      expect(
        d(resp(review: true, warnings: ['name_uncertain'])),
        SaveDecision.review,
      );
    });
    test('số tiền 0, âm hoặc vượt trần -> chờ xác nhận', () {
      expect(d(resp(amount: 0)), SaveDecision.review);
      expect(d(resp(amount: -5)), SaveDecision.review);
      expect(d(resp(amount: 2000000000)), SaveDecision.review);
    });
  });
}
