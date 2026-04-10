import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'receipt_print_service.dart';

// ── Brand palette ──────────────────────────────────────────────────────────────────────────────
final _colNavy = PdfColor.fromHex('1B3C6B');
final _colBlue = PdfColor.fromHex('1D5FAB');
final _colLightBg = PdfColor.fromHex('E8F0FB');
final _colTblHdr = PdfColor.fromHex('C8DBEF');
final _colRowAlt = PdfColor.fromHex('F5F9FF');
final _colDivider = PdfColor.fromHex('CBD5E1');
final _colLabel = PdfColor.fromHex('374151');
final _colMuted = PdfColor.fromHex('6B7280');
final _colTeal = PdfColor.fromHex('0E7490');

Future<Uint8List> buildNstuPrescriptionPdf({
  required String patientName,
  required String mobile,
  required String age,
  required String gender,
  required String bloodGroup,
  required String patientId,
  required String date,
  required String bp,
  required String temperature,
  required String diagnosis,
  required String suggestedTests,
  required String advice,
  required String nextVisit,
  required List<PrescriptionMedicineLine> medicines,
}) async {
  final pdf = pw.Document();

  final logoBytes = (await rootBundle.load(
    'assets/images/nstu_logo.jpg',
  )).buffer.asUint8List();
  final logo = pw.MemoryImage(logoBytes);

  pw.MemoryImage? headingImage;
  try {
    final bytes = (await rootBundle.load(
      'assets/images/prescription_download_heading.png',
    )).buffer.asUint8List();
    headingImage = pw.MemoryImage(bytes);
  } catch (_) {}

  pw.Font? kalpurush;
  try {
    final fontData = (await rootBundle.load(
      'assets/fonts/Kalpurush.ttf',
    )).buffer.asByteData();
    kalpurush = pw.Font.ttf(fontData);
  } catch (_) {}

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      build: (context) => [
        _pdfHeader(logo, headingImage, kalpurush),
        pw.SizedBox(height: 8),
        pw.Divider(color: _colDivider, thickness: 1),
        pw.SizedBox(height: 6),
        _pdfPatientBar(
          name: patientName,
          mobile: mobile,
          age: age,
          gender: gender,
          bloodGroup: bloodGroup,
          date: date,
        ),
        pw.SizedBox(height: 6),
        pw.Divider(color: _colDivider, thickness: 1),
        pw.SizedBox(height: 10),
        _pdfBody(
          diagnosis: diagnosis,
          bp: bp,
          temperature: temperature,
          advice: advice,
          suggestedTests: suggestedTests,
          medicines: medicines,
        ),
        pw.SizedBox(height: 20),
        pw.Divider(color: _colDivider, thickness: .5),
        pw.SizedBox(height: 6),
        _pdfFooter(patientId: patientId, nextVisit: nextVisit),
      ],
    ),
  );

  return pdf.save();
}

// ── Header ──────────────────────────────────────────────────────────────────────────────
pw.Widget _pdfHeader(
  pw.ImageProvider logo,
  pw.MemoryImage? headingImage,
  pw.Font? banglaFont,
) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: [
      pw.SizedBox(
        width: 64,
        height: 64,
        child: pw.Image(logo, fit: pw.BoxFit.contain),
      ),
      pw.SizedBox(width: 14),
      pw.Expanded(
        child: pw.Align(
          alignment: pw.Alignment.center,
          child: headingImage != null
              ? pw.SizedBox(
                  height: 70,
                  child: pw.Image(headingImage, fit: pw.BoxFit.contain),
                )
              : pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    if (banglaFont != null) ...[
                      pw.Text(
                        'মেডিকেল সেন্টার',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          font: banglaFont,
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'নোয়াখালী বিজ্ঞান ও প্রযুক্তি বিশ্ববিদ্যালয়',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(font: banglaFont, fontSize: 14),
                      ),
                      pw.SizedBox(height: 4),
                    ],
                    pw.Text(
                      'Noakhali Science and Technology University',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 15,
                        fontWeight: pw.FontWeight.bold,
                        color: _colBlue,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    ],
  );
}

// ── Patient Info Bar ───────────────────────────────────────────────────────────────────
pw.Widget _pdfPatientBar({
  required String name,
  required String mobile,
  required String age,
  required String gender,
  required String bloodGroup,
  required String date,
}) {
  return pw.Container(
    decoration: pw.BoxDecoration(
      color: _colLightBg,
      borderRadius: pw.BorderRadius.circular(4),
    ),
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    child: pw.Row(
      children: [
        pw.Expanded(flex: 5, child: _infoCell('PATIENT', name)),
        _infoDivider(),
        pw.Expanded(flex: 3, child: _infoCell('MOBILE', mobile)),
        _infoDivider(),
        pw.Expanded(flex: 2, child: _infoCell('AGE', age)),
        _infoDivider(),
        pw.Expanded(flex: 2, child: _infoCell('GENDER', gender)),
        _infoDivider(),
        pw.Expanded(
          flex: 2,
          child: _infoCell('BLOOD', bloodGroup.isEmpty ? '-' : bloodGroup),
        ),
        _infoDivider(),
        pw.Expanded(flex: 3, child: _infoCell('DATE', date)),
      ],
    ),
  );
}

pw.Widget _infoDivider() => pw.Container(
  width: 1,
  height: 30,
  margin: const pw.EdgeInsets.symmetric(horizontal: 6),
  decoration: pw.BoxDecoration(
    border: pw.Border(left: pw.BorderSide(color: _colDivider, width: 1)),
  ),
);

pw.Widget _infoCell(String label, String value) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(label, style: pw.TextStyle(fontSize: 7.5, color: _colMuted)),
      pw.SizedBox(height: 2),
      pw.Text(
        value,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: _colNavy,
        ),
      ),
    ],
  );
}

// ── Body ─────────────────────────────────────────────────────────────────────────────────
pw.Widget _pdfBody({
  required String diagnosis,
  required String bp,
  required String temperature,
  required String advice,
  required String suggestedTests,
  required List<PrescriptionMedicineLine> medicines,
}) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.SizedBox(
        width: 162,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _sectionBox('CHIEF COMPLAINT (C/C)', diagnosis),
            pw.SizedBox(height: 10),
            _sectionBox(
              'ON EXAMINATION (O/E)',
              'BP:   $bp\nTemp: $temperature',
            ),
            pw.SizedBox(height: 10),
            _sectionBox('ADVICE', advice),
            pw.SizedBox(height: 10),
            _sectionBox('INVESTIGATION (INV)', suggestedTests),
          ],
        ),
      ),
      pw.Container(
        width: 1,
        height: 340,
        margin: const pw.EdgeInsets.symmetric(horizontal: 12),
        decoration: pw.BoxDecoration(
          border: pw.Border(left: pw.BorderSide(color: _colDivider, width: 1)),
        ),
      ),
      pw.Expanded(child: _pdfRxSection(medicines)),
    ],
  );
}

pw.Widget _sectionBox(String title, String content) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(
        width: double.infinity,
        decoration: pw.BoxDecoration(
          color: _colTblHdr,
          borderRadius: const pw.BorderRadius.only(
            topLeft: pw.Radius.circular(3),
            topRight: pw.Radius.circular(3),
          ),
        ),
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: _colNavy,
          ),
        ),
      ),
      pw.Container(
        width: double.infinity,
        decoration: pw.BoxDecoration(
          border: pw.Border(
            left: pw.BorderSide(color: _colDivider, width: .6),
            right: pw.BorderSide(color: _colDivider, width: .6),
            bottom: pw.BorderSide(color: _colDivider, width: .6),
          ),
        ),
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(
          content.trim().isEmpty ? '-' : content,
          style: pw.TextStyle(fontSize: 10, lineSpacing: 2.5, color: _colLabel),
        ),
      ),
    ],
  );
}

// ── Rx Section ──────────────────────────────────────────────────────────────────────────────
pw.Widget _pdfRxSection(List<PrescriptionMedicineLine> medicines) {
  final items = medicines.isEmpty
      ? [
          const PrescriptionMedicineLine(
            medicine: 'No medication prescribed',
            dosage: '-',
            frequency: '-',
            duration: '-',
          ),
        ]
      : medicines;

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        'Rx',
        style: pw.TextStyle(
          fontSize: 30,
          fontStyle: pw.FontStyle.italic,
          color: _colBlue,
        ),
      ),
      pw.SizedBox(height: 8),
      pw.Table(
        columnWidths: const {
          0: pw.FlexColumnWidth(4),
          1: pw.FlexColumnWidth(2),
          2: pw.FlexColumnWidth(3),
          3: pw.FlexColumnWidth(2),
          4: pw.FlexColumnWidth(3),
        },
        defaultVerticalAlignment: pw.TableCellVerticalAlignment.top,
        children: [
          pw.TableRow(
            decoration: pw.BoxDecoration(color: _colTblHdr),
            children:
                ['Medicine', 'Dosage', 'Frequency', 'Duration', 'Instructions']
                    .map(
                      (h) => pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                          vertical: 5,
                          horizontal: 5,
                        ),
                        child: pw.Text(
                          h.toUpperCase(),
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: _colNavy,
                          ),
                        ),
                      ),
                    )
                    .toList(),
          ),
          ...items.asMap().entries.map(
            (entry) => pw.TableRow(
              decoration: pw.BoxDecoration(
                color: entry.key.isOdd ? _colRowAlt : PdfColors.white,
              ),
              children: [
                _tCell(entry.value.medicine),
                _tCell(entry.value.dosage.isEmpty ? '-' : entry.value.dosage),
                _tCell(entry.value.frequency),
                _tCell(entry.value.duration),
                _tCell(
                  entry.value.notes.isEmpty ? '-' : entry.value.notes,
                  muted: true,
                ),
              ],
            ),
          ),
        ],
      ),
    ],
  );
}

pw.Widget _tCell(String text, {bool muted = false}) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 5),
  child: pw.Text(
    text,
    style: pw.TextStyle(fontSize: 10, color: muted ? _colMuted : _colLabel),
  ),
);

// ── Footer ─────────────────────────────────────────────────────────────────────────────────
pw.Widget _pdfFooter({required String patientId, required String nextVisit}) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    crossAxisAlignment: pw.CrossAxisAlignment.end,
    children: [
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Patient ID: $patientId',
            style: pw.TextStyle(fontSize: 10, color: _colMuted),
          ),
          if (nextVisit.isNotEmpty && nextVisit != '-')
            pw.Text(
              'Next Visit: $nextVisit',
              style: pw.TextStyle(fontSize: 10, color: _colTeal),
            ),
        ],
      ),
      pw.SizedBox(
        width: 140,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Container(
              height: 1,
              width: double.infinity,
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  top: pw.BorderSide(color: _colNavy, width: 1),
                ),
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Authorised Signature',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 9, color: _colLabel),
            ),
          ],
        ),
      ),
    ],
  );
}
