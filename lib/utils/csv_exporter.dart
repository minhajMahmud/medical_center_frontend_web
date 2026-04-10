import 'csv_exporter_stub.dart' if (dart.library.html) 'csv_exporter_web.dart';

Future<void> exportCsvFile({
  required String fileName,
  required String csvContent,
}) {
  return exportCsvFileImpl(fileName: fileName, csvContent: csvContent);
}
