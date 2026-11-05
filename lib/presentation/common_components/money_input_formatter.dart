import 'package:flutter/services.dart';

import '../../utils/money.dart';

/// Gõ "2000000" tự hiện "2.000.000".
class MoneyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final v = Money.parse(newValue.text);
    if (v == null) {
      return const TextEditingValue(text: '');
    }
    final text = Money.format(v, symbol: false);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
