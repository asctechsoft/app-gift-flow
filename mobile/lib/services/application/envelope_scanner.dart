import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

class ScanResult {
  ScanResult({required this.lines, this.amountVnd});

  /// Các dòng chữ nhận được (ứng viên cho tên khách) - người dùng tự chọn.
  final List<String> lines;

  /// Số tiền nếu đọc được rõ ràng trên phong bì (vd "500.000", "2tr").
  final int? amountVnd;
}

/// Quét phong bì bằng ML Kit Text Recognition (chạy trên máy, không gửi ảnh đi đâu).
/// Chỉ GỢI Ý - không bao giờ tự lưu (khoản tiền luôn do người dùng xác nhận).
class EnvelopeScanner {
  final ImagePicker _picker = ImagePicker();

  Future<ScanResult?> scan({ImageSource source = ImageSource.camera}) async {
    final shot = await _picker.pickImage(source: source, imageQuality: 85);
    if (shot == null) return null;
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final text =
          await recognizer.processImage(InputImage.fromFilePath(shot.path));
      return parse(text.text);
    } finally {
      await recognizer.close();
    }
  }

  /// Tách dòng + dò số tiền từ văn bản OCR (tách riêng để test được).
  static ScanResult parse(String raw) {
    final lines = raw
        .split(RegExp(r'[\r\n]+'))
        .map((l) => l.trim())
        .where((l) => l.length >= 2)
        .toList();
    int? amount;
    final amountRe = RegExp(
      r'(\d{1,3}(?:[.,]\d{3})+|\d+(?:[.,]\d+)?)\s*(k|nghìn|ngàn|tr|triệu|đ|vnđ|vnd)?',
      caseSensitive: false,
    );
    for (final l in lines) {
      for (final m in amountRe.allMatches(l)) {
        final numStr = m.group(1)!;
        final unit = (m.group(2) ?? '').toLowerCase();
        double v;
        if (RegExp(r'^\d{1,3}([.,]\d{3})+$').hasMatch(numStr)) {
          v = double.parse(numStr.replaceAll(RegExp(r'[.,]'), ''));
        } else {
          v = double.tryParse(numStr.replaceAll(',', '.')) ?? 0;
        }
        if (unit == 'k' || unit == 'nghìn' || unit == 'ngàn') v *= 1000;
        if (unit == 'tr' || unit == 'triệu') v *= 1000000;
        // chỉ nhận số đủ lớn để chắc là tiền (tránh số điện thoại/ngày tháng)
        final isPhone = RegExp(r'^0\d{8,10}$').hasMatch(numStr);
        if (!isPhone && v >= 10000 && v <= 1000000000 && numStr.length <= 11) {
          amount = v.round();
        }
      }
    }
    // dòng chỉ gồm số/ký hiệu không phải tên
    final names = lines
        .where((l) => RegExp(r'\p{L}', unicode: true).hasMatch(l))
        .toList();
    return ScanResult(lines: names, amountVnd: amount);
  }
}
