import 'dart:io';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/data_models/gift_event.dart';
import '../../models/data_models/gift_record.dart';
import '../../models/ui_models/gift_status.dart';
import '../../utils/text_utils.dart';

class ExportColumns {
  ExportColumns({
    this.guest = true,
    this.amount = true,
    this.relationship = true,
    this.note = false,
    this.side = true,
  });
  bool side;
  bool guest;
  bool amount;
  bool relationship;
  bool note;
}

class ExportResult {
  ExportResult(this.path, this.rows, this.confirmedTotal);
  final String path;
  final int rows;

  /// Tổng confirmed ghi trong file (để đối soát với màn Thống kê - BR10).
  final int confirmedTotal;
}

/// Sinh file .xlsx cục bộ rồi mở share sheet hệ thống (S10).
class ExportService {
  /// [labels]: tiêu đề cột đã dịch.
  Future<ExportResult> build({
    required GiftEvent event,
    required List<GiftRecord> gifts,
    required ExportColumns columns,
    required bool includePending,
    required Map<String, String> labels,
  }) async {
    final ex = Excel.createExcel();
    final name = labels['sheet'] ?? 'GiftFlow';
    final sheet = ex[name];
    ex.delete('Sheet1');
    ex.setDefaultSheet(name);

    final header = <String>[
      labels['no']!,
      if (columns.guest) labels['guest']!,
      if (columns.amount) labels['amount']!,
      if (columns.relationship) labels['relationship']!,
      if (columns.side) labels['side']!,
      if (columns.note) labels['note']!,
      if (includePending) labels['status']!,
    ];
    sheet.appendRow(header.map<CellValue>((h) => TextCellValue(h)).toList());
    for (var i = 0; i < header.length; i++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          .cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#EDE3FF'),
      );
    }

    var total = 0;
    var n = 0;
    for (final g in gifts) {
      n++;
      final confirmed = g.status == GiftStatus.confirmed;
      if (confirmed) total += g.amountVnd;
      sheet.appendRow(<CellValue>[
        IntCellValue(n),
        if (columns.guest) TextCellValue(TextUtils.excelSafe(g.guestName)),
        if (columns.amount) IntCellValue(g.amountVnd),
        if (columns.relationship)
          TextCellValue(TextUtils.excelSafe(g.relationship ?? '')),
        if (columns.side) TextCellValue(labels[g.side == 'parents' ? 'side_parents' : 'side_mine']!),
        if (columns.note) TextCellValue(TextUtils.excelSafe(g.note ?? '')),
        if (includePending)
          TextCellValue(
            confirmed ? labels['confirmed']! : labels['pending']!,
          ),
      ]);
    }
    // Dòng tổng = SUM(amount) của bản ghi đã xác nhận.
    if (columns.amount) {
      final cells = <CellValue>[
        TextCellValue(''),
        if (columns.guest) TextCellValue(labels['total']!),
        IntCellValue(total),
        if (columns.relationship) TextCellValue(''),
        if (columns.side) TextCellValue(''),
        if (columns.note) TextCellValue(''),
        if (includePending) TextCellValue(''),
      ];
      sheet.appendRow(cells);
    }

    final bytes = ex.encode();
    if (bytes == null) throw StateError('excel encode failed');
    final dir = await getTemporaryDirectory();
    final safe = event.name
        .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final file = File('${dir.path}/GiftFlow_${safe}_$stamp.xlsx');
    await file.writeAsBytes(bytes, flush: true);
    return ExportResult(file.path, gifts.length, total);
  }

  Future<void> share(ExportResult r, {String? subject}) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(
            r.path,
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        ],
        subject: subject,
      ),
    );
  }
}
