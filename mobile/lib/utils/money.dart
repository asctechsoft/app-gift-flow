/// Định dạng/parse tiền VND: 2.000.000 đ
class Money {
  Money._();

  static String format(int vnd, {bool symbol = true}) {
    final neg = vnd < 0;
    final s = vnd.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return '${neg ? '-' : ''}$buf${symbol ? ' đ' : ''}';
  }

  /// "2.000.000", "2,000,000 đ", "2000000" -> 2000000. Không hợp lệ -> null.
  static int? parse(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty || digits.length > 12) return null;
    return int.tryParse(digits);
  }
}
