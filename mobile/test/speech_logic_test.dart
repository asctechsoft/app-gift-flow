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

  group('TurnBuffer', () {
    late List<String> live;
    late List<String> sent;
    late DateTime now;
    late TurnBuffer t;

    setUp(() {
      live = [];
      sent = [];
      now = DateTime(2026, 1, 1, 10);
      t = TurnBuffer(onLive: live.add, onUtterance: sent.add, clock: () => now);
    });

    test('partial chỉ hiện chữ, KHÔNG gửi', () {
      t.onResult('Anh', isFinal: false);
      t.onResult('Anh Long mừng', isFinal: false);
      expect(sent, isEmpty);
      expect(live.last, 'Anh Long mừng');
      expect(t.text, 'Anh Long mừng');
    });

    test('final được chốt vào câu nhưng chưa gửi cho tới khi send()', () {
      t.onResult('Anh Long mừng hai triệu', isFinal: true);
      expect(sent, isEmpty);
      expect(t.hasText, isTrue);
      expect(t.send(), isTrue);
      expect(sent, ['Anh Long mừng hai triệu']);
      expect(t.hasText, isFalse);
      expect(live.last, '');
    });

    test('ngập ngừng: nhiều phiên nhận dạng trong một lượt gom thành MỘT câu', () {
      t.onResult('Anh Quang', isFinal: true); // phiên 1 (hệ thống tự ngắt)
      t.onResult('12 triệu', isFinal: false); // phiên 2 sau khi nghe lại
      expect(t.text, 'Anh Quang 12 triệu');
      t.onResult('12 triệu', isFinal: true);
      t.send();
      expect(sent, ['Anh Quang 12 triệu']);
    });

    test('callback final bị gọi lặp -> không gộp đôi, không gửi trùng', () {
      t.onResult('Anh Long mừng hai triệu', isFinal: true);
      t.onResult('Anh Long mừng hai triệu', isFinal: true);
      expect(t.text, 'Anh Long mừng hai triệu');
      t.send();
      now = now.add(const Duration(seconds: 1));
      t.onResult('Anh Long mừng hai triệu', isFinal: true);
      expect(t.send(), isFalse); // trùng trong cửa sổ chống trùng
      expect(sent, hasLength(1));
    });

    test('máy không gửi final: commitPartial giữ câu partial cuối', () {
      t.onResult('Chị Mai mừng năm trăm', isFinal: false);
      t.commitPartial();
      expect(t.text, 'Chị Mai mừng năm trăm');
      t.send();
      expect(sent, ['Chị Mai mừng năm trăm']);
    });

    test('hai câu khác nhau ở hai lượt -> gửi cả hai, không nhầm transcript', () {
      t.onResult('Anh Long mừng hai triệu', isFinal: true);
      t.send();
      now = now.add(const Duration(seconds: 10));
      t.reset();
      t.onResult('Chị Mai mừng năm trăm', isFinal: true);
      t.send();
      expect(sent, ['Anh Long mừng hai triệu', 'Chị Mai mừng năm trăm']);
    });

    test('cùng nội dung nhưng cách xa hơn cửa sổ chống trùng -> hợp lệ', () {
      t.onResult('Anh Long mừng hai triệu', isFinal: true);
      t.send();
      now = now.add(const Duration(seconds: 30));
      t.onResult('Anh Long mừng hai triệu', isFinal: true);
      t.send();
      expect(sent, hasLength(2));
    });

    test('câu quá ngắn/nhiễu bị bỏ', () {
      t.onResult('ờ', isFinal: true);
      expect(t.send(), isFalse);
      expect(sent, isEmpty);
    });

    test('reset bỏ chữ của lượt cũ', () {
      t.onResult('Anh Long', isFinal: false);
      t.reset();
      expect(t.send(), isFalse);
      expect(sent, isEmpty);
    });

    test('resultCount đếm mọi callback (chẩn đoán)', () {
      t.onResult('a b c', isFinal: false);
      t.onResult('a b c d', isFinal: true);
      expect(t.resultCount, 2);
    });
  });

  group('voiceHint (nhắc khi nói quá nhỏ)', () {
    const s = Duration(seconds: 1);
    test('chưa quá 4s thì chưa nhắc', () {
      expect(voiceHint(elapsed: s * 3, hasText: false, maxLevel: -2), VoiceHint.none);
    });
    test('đã có chữ thì không nhắc', () {
      expect(voiceHint(elapsed: s * 10, hasText: true, maxLevel: -2), VoiceHint.none);
    });
    test('mic gần như im sau 4s -> nói to hơn', () {
      expect(voiceHint(elapsed: s * 5, hasText: false, maxLevel: 0.2), VoiceHint.tooQuiet);
    });
    test('có tiếng nhưng không ra chữ -> nói rõ hơn', () {
      expect(voiceHint(elapsed: s * 5, hasText: false, maxLevel: 6), VoiceHint.notRecognized);
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
