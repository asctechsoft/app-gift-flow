import 'package:flutter_test/flutter_test.dart';
import 'package:gift_flow/services/application/speech_logic.dart';

void main() {
  group('pickVietnameseLocale', () {
    test('ưu tiên vi_VN dù đứng sau', () {
      expect(pickVietnameseLocale(['en_US', 'vi', 'vi_VN']), 'vi_VN');
    });
    test('chấp nhận vi-VN (gạch ngang) và vi bất kỳ', () {
      expect(pickVietnameseLocale(['en_US', 'vi-VN']), 'vi-VN');
      expect(pickVietnameseLocale(['en_US', 'vi']), 'vi');
    });
    test('không có tiếng Việt -> null (không tự đổi sang ngôn ngữ khác)', () {
      expect(pickVietnameseLocale(['en_US', 'fr_FR']), isNull);
      expect(pickVietnameseLocale([]), isNull);
    });
  });

  group('UtteranceTracker', () {
    late List<String> live;
    late List<String> sent;
    late DateTime now;
    late UtteranceTracker t;

    setUp(() {
      live = [];
      sent = [];
      now = DateTime(2026, 1, 1, 10);
      t = UtteranceTracker(
        onLive: live.add,
        onUtterance: sent.add,
        clock: () => now,
      );
    });

    test('partial chỉ hiện chữ, KHÔNG gửi', () {
      t.onResult('Anh', isFinal: false);
      t.onResult('Anh Long mừng', isFinal: false);
      expect(sent, isEmpty);
      expect(live.last, 'Anh Long mừng');
      expect(t.pending, 'Anh Long mừng');
    });

    test('final gửi đúng một lần và xoá chữ tạm', () {
      t.onResult('Anh Long mừng', isFinal: false);
      t.onResult('Anh Long mừng hai triệu', isFinal: true);
      expect(sent, ['Anh Long mừng hai triệu']);
      expect(t.pending, isEmpty);
      expect(live.last, '');
    });

    test('callback final bị gọi lặp -> không gửi trùng', () {
      t.onResult('Anh Long mừng hai triệu', isFinal: true);
      t.onResult('Anh Long mừng hai triệu', isFinal: true);
      now = now.add(const Duration(seconds: 1));
      t.onResult('Anh Long mừng hai triệu', isFinal: true);
      expect(sent, hasLength(1));
    });

    test('máy không gửi final: flush gửi câu partial gần nhất', () {
      t.onResult('Chị Mai mừng năm trăm', isFinal: false);
      t.flush();
      expect(sent, ['Chị Mai mừng năm trăm']);
      t.flush(); // flush lần hai không gửi lại
      expect(sent, hasLength(1));
    });

    test('final tới sau khi đã flush (dài hơn) -> bỏ, không tạo 2 bản ghi', () {
      t.onResult('Chị Mai mừng năm trăm', isFinal: false);
      t.flush();
      now = now.add(const Duration(seconds: 1));
      t.onResult('Chị Mai mừng năm trăm nghìn', isFinal: true);
      expect(sent, ['Chị Mai mừng năm trăm']);
    });

    test('hai câu khác nhau ở hai lượt -> gửi cả hai, không nhầm transcript', () {
      t.onResult('Anh Long mừng hai triệu', isFinal: true);
      now = now.add(const Duration(seconds: 10));
      t.reset();
      t.onResult('Chị Mai mừng năm trăm', isFinal: true);
      expect(sent, ['Anh Long mừng hai triệu', 'Chị Mai mừng năm trăm']);
    });

    test('cùng nội dung nhưng cách xa hơn cửa sổ chống trùng -> hợp lệ', () {
      t.onResult('Anh Long mừng hai triệu', isFinal: true);
      now = now.add(const Duration(seconds: 30));
      t.onResult('Anh Long mừng hai triệu', isFinal: true);
      expect(sent, hasLength(2));
    });

    test('câu quá ngắn/nhiễu bị bỏ', () {
      t.onResult('ờ', isFinal: true);
      t.onResult('  ', isFinal: true);
      expect(sent, isEmpty);
    });

    test('reset bỏ partial của lượt cũ', () {
      t.onResult('Anh Long', isFinal: false);
      t.reset();
      t.flush();
      expect(sent, isEmpty);
    });

    test('resultCount đếm mọi callback (chẩn đoán)', () {
      t.onResult('a b c', isFinal: false);
      t.onResult('a b c d', isFinal: true);
      expect(t.resultCount, 2);
    });
  });

  group('TurnPolicy (không vòng lặp mic vô hạn)', () {
    test('lượt rỗng -> không tự nghe lại', () {
      final p = TurnPolicy();
      expect(p.shouldAutoRestart(turnHadUtterance: false), isFalse);
    });
    test('lượt có câu -> nghe tiếp', () {
      final p = TurnPolicy();
      expect(p.shouldAutoRestart(turnHadUtterance: true), isTrue);
    });
    test('có trần số lượt tự động, người dùng chạm mic thì đếm lại', () {
      final p = TurnPolicy();
      for (var i = 0; i < TurnPolicy.maxAutoTurns; i++) {
        expect(p.shouldAutoRestart(turnHadUtterance: true), isTrue);
      }
      expect(p.shouldAutoRestart(turnHadUtterance: true), isFalse);
      p.userStartedTurn();
      expect(p.shouldAutoRestart(turnHadUtterance: true), isTrue);
    });
  });
}
