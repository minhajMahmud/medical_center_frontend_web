import 'package:flutter/services.dart';

Future<void> exportCsvFileImpl({
  required String fileName,
  required String csvContent,
}) async {
  await Clipboard.setData(ClipboardData(text: csvContent));
}
