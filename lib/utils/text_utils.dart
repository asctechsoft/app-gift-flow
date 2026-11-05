/// Chuẩn hoá chuỗi tiếng Việt để tìm kiếm không dấu + escape cho Excel.
class TextUtils {
  TextUtils._();

  static const _map = <String, String>{
    'àáạảãâầấậẩẫăằắặẳẵ': 'a',
    'èéẹẻẽêềếệểễ': 'e',
    'ìíịỉĩ': 'i',
    'òóọỏõôồốộổỗơờớợởỡ': 'o',
    'ùúụủũưừứựửữ': 'u',
    'ỳýỵỷỹ': 'y',
    'đ': 'd',
  };

  static String fold(String s) {
    final lower = s.toLowerCase().trim();
    final b = StringBuffer();
    for (final r in lower.runes) {
      final ch = String.fromCharCode(r);
      var out = ch;
      for (final e in _map.entries) {
        if (e.key.contains(ch)) {
          out = e.value;
          break;
        }
      }
      b.write(out);
    }
    return b.toString();
  }

  /// Chống formula injection khi xuất Excel (BR/Export).
  static String excelSafe(String s) {
    if (s.isEmpty) return s;
    const risky = ['=', '+', '-', '@', '\t', '\r'];
    return risky.contains(s[0]) ? "'$s" : s;
  }
}
