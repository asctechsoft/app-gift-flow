import 'package:intl/intl.dart';

class DateFmt {
  DateFmt._();

  /// yyyy-MM-dd (lưu) -> dd/MM/yyyy (hiển thị)
  static String display(String isoDate) {
    final d = DateTime.tryParse(isoDate);
    return d == null ? isoDate : DateFormat('dd/MM/yyyy').format(d);
  }

  static String iso(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  static String dateTime(DateTime d) =>
      DateFormat('dd/MM/yyyy HH:mm').format(d);
}
