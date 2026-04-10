export 'receipt_print_service_stub.dart'
    if (dart.library.html) 'receipt_print_service_web.dart';

class ReceiptLineItem {
  const ReceiptLineItem({
    required this.code,
    required this.name,
    required this.type,
    required this.amount,
    this.extra = '',
  });

  final String code;
  final String name;
  final String type;
  final double amount;
  final String extra;
}

class PrescriptionMedicineLine {
  const PrescriptionMedicineLine({
    required this.medicine,
    required this.dosage,
    required this.frequency,
    required this.duration,
    this.notes = '',
  });

  final String medicine;
  final String dosage;
  final String frequency;
  final String duration;
  final String notes;
}

String buildNstuPrescriptionHtml({
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
}) {
  final safeTemperature = _escapeHtml(temperature).replaceAll('°', '&deg;');

  final medicineRows = medicines.isEmpty
      ? '<tr><td>No medication prescribed</td><td>-</td><td>-</td><td>-</td><td>-</td></tr>'
      : medicines
            .map(
              (item) =>
                  '<tr>'
                  '<td>${_escapeHtml(item.medicine)}</td>'
                  '<td>${item.dosage.isEmpty ? '-' : _escapeHtml(item.dosage)}</td>'
                  '<td>${_escapeHtml(item.frequency)}</td>'
                  '<td>${_escapeHtml(item.duration)}</td>'
                  '<td class="instr">${item.notes.isEmpty ? '-' : _escapeHtml(item.notes)}</td>'
                  '</tr>',
            )
            .join();

  return '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8" />
  <title>Prescription \u2013 ${_escapeHtml(patientName)}</title>
  <style>
    @page { size: A4; margin: 10mm; }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    :root {
      --navy:  #1B3C6B;
      --blue:  #1D5FAB;
      --light: #E8F0FB;
      --thdr:  #C8DBEF;
      --ralt:  #F5F9FF;
      --dvdr:  #CBD5E1;
      --lbl:   #374151;
      --muted: #6B7280;
      --teal:  #0E7490;
    }
    body { font-family: Arial, Helvetica, sans-serif; color: var(--lbl); background: #fff; }
    .sheet { padding: 8px 6px 14px; }

    /* Header */
    .hdr { display: flex; align-items: center; gap: 14px; }
    .hdr img.logo { width: 66px; height: 66px; object-fit: contain; display: block; }
    .hdr .tw { flex: 1; display: flex; justify-content: center; align-items: center; }
    .hdr img.himg { max-height: 78px; object-fit: contain; display: block; }
    hr.thick { border: none; border-top: 1.5px solid var(--dvdr); margin: 8px 0 6px; }
    hr.thin  { border: none; border-top: .6px  solid var(--dvdr); margin: 4px 0; }

    /* Info bar */
    .ibar { display: flex; background: var(--light); border-radius: 5px; padding: 8px 10px; align-items: flex-start; }
    .ic { flex: 1; padding: 0 8px; }
    .ic:first-child { padding-left: 0; }
    .ic:last-child  { padding-right: 0; }
    .ic + .ic { border-left: 1px solid var(--dvdr); }
    .ic .lbl { font-size: 8.5px; color: var(--muted); text-transform: uppercase; letter-spacing: .5px; }
    .ic .val { font-size: 11px; font-weight: 700; color: var(--navy); margin-top: 2px; }

    /* Body grid */
    .bgrid { display: grid; grid-template-columns: 170px 1px 1fr; gap: 0; margin-top: 10px; }
    .bsep  { background: var(--dvdr); margin: 0 12px; }

    /* Section boxes */
    .sbx { margin-bottom: 10px; }
    .sbx .st { font-size: 8.5px; font-weight: 700; color: var(--navy); background: var(--thdr);
               padding: 3px 6px; border-radius: 3px 3px 0 0; text-transform: uppercase; letter-spacing: .3px; }
    .sbx .sb { font-size: 11px; color: var(--lbl); border: .6px solid var(--dvdr); border-top: none;
               border-radius: 0 0 3px 3px; padding: 6px; min-height: 28px; white-space: pre-wrap; line-height: 1.5; }

    /* Rx */
    .rxh { font-size: 30px; font-weight: 700; font-style: italic; color: var(--blue); line-height: 1; margin-bottom: 8px; }

    /* Medicine table */
    .mtbl { width: 100%; border-collapse: collapse; font-size: 11px; }
    .mtbl th { background: var(--thdr); color: var(--navy); font-size: 8.5px; font-weight: 700;
               text-transform: uppercase; letter-spacing: .3px; padding: 5px; text-align: left; }
    .mtbl td { padding: 5px; color: var(--lbl); vertical-align: top; }
    .mtbl tbody tr:nth-child(odd)  td { background: var(--ralt); }
    .mtbl tbody tr:nth-child(even) td { background: #fff; }
    .instr { font-size: 9.5px; color: var(--muted); }

    /* Footer */
    .ftr { display: flex; justify-content: space-between; align-items: flex-end; margin-top: 14px; }
    .pid { font-size: 10px; color: var(--muted); }
    .nv  { font-size: 10px; color: var(--teal); margin-top: 2px; }
    .sig { width: 140px; text-align: center; }
    .sig-line  { border-top: 1px solid var(--navy); margin-bottom: 4px; }
    .sig-label { font-size: 9px; color: var(--lbl); }

    @media print { .sheet { padding: 0; } }
  </style>
</head>
<body>
<div class="sheet">
  <div class="hdr">
    <img class="logo" src="assets/assets/images/nstu_logo.jpg" alt="NSTU Logo" />
    <div class="tw">
      <img class="himg" src="assets/assets/images/prescription_download_heading.png" alt="NSTU Medical Center" />
    </div>
  </div>
  <hr class="thick" />
  <div class="ibar">
    <div class="ic"><div class="lbl">Patient</div><div class="val">${_escapeHtml(patientName)}</div></div>
    <div class="ic"><div class="lbl">Mobile</div><div class="val">${_escapeHtml(mobile)}</div></div>
    <div class="ic"><div class="lbl">Age</div><div class="val">${_escapeHtml(age)}</div></div>
    <div class="ic"><div class="lbl">Gender</div><div class="val">${_escapeHtml(gender)}</div></div>
    <div class="ic"><div class="lbl">Blood</div><div class="val">${bloodGroup.isEmpty ? '-' : _escapeHtml(bloodGroup)}</div></div>
    <div class="ic"><div class="lbl">Date</div><div class="val">${_escapeHtml(date)}</div></div>
  </div>
  <hr class="thick" style="margin-top:8px;" />
  <div class="bgrid">
    <div>
      <div class="sbx">
        <div class="st">Chief Complaint (C/C)</div>
        <div class="sb">${diagnosis.trim().isEmpty ? '-' : _escapeHtml(diagnosis)}</div>
      </div>
      <div class="sbx">
        <div class="st">On Examination (O/E)</div>
        <div class="sb">BP:   ${_escapeHtml(bp)}&#10;Temp: $safeTemperature</div>
      </div>
      <div class="sbx">
        <div class="st">Advice</div>
        <div class="sb">${advice.trim().isEmpty ? '-' : _escapeHtml(advice)}</div>
      </div>
      <div class="sbx">
        <div class="st">Investigation (Inv)</div>
        <div class="sb">${suggestedTests.trim().isEmpty ? '-' : _escapeHtml(suggestedTests)}</div>
      </div>
    </div>
    <div class="bsep"></div>
    <div>
      <div class="rxh">Rx</div>
      <table class="mtbl">
        <thead>
          <tr>
            <th style="width:27%">Medicine</th>
            <th style="width:13%">Dosage</th>
            <th style="width:20%">Frequency</th>
            <th style="width:12%">Duration</th>
            <th>Instructions</th>
          </tr>
        </thead>
        <tbody>
          $medicineRows
        </tbody>
      </table>
    </div>
  </div>
  <hr class="thin" style="margin-top:16px;" />
  <div class="ftr">
    <div>
      <div class="pid">Patient ID: ${_escapeHtml(patientId)}</div>
      ${nextVisit.isEmpty || nextVisit == '-' ? '' : '<div class="nv">Next Visit: ${_escapeHtml(nextVisit)}</div>'}
    </div>
    <div class="sig">
      <div class="sig-line"></div>
      <div class="sig-label">Authorised Signature</div>
    </div>
  </div>
</div>
</body>
</html>
''';
}

String buildNstuPaymentReceiptHtml({
  required String title,
  required String patientName,
  required String mobile,
  required String testName,
  required String paymentMethod,
  required String transactionId,
  required String paymentDate,
  required double amount,
  String footerNote = 'Printed from NSTU Medical Center.',
}) {
  return '''
<!doctype html>
<html>
<head>
    <meta charset="utf-8" />
    <title>${_escapeHtml(title)}</title>
    <style>
        @page { margin: 14mm; }
        body { font-family: Arial, Helvetica, sans-serif; color: #0f172a; margin: 0; }
        .sheet { border: 1px solid #e2e8f0; border-radius: 12px; padding: 18px; }
        .brand { display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px; }
        .brand h1 { margin: 0; font-size: 22px; letter-spacing: .4px; }
        .brand p { margin: 0; color: #475569; font-size: 12px; }
        .title { margin: 8px 0 12px 0; font-size: 20px; font-weight: 800; }
        .meta { display: grid; grid-template-columns: 1fr 1fr; gap: 8px 20px; margin-bottom: 12px; }
        .meta div { font-size: 13px; }
        table { width: 100%; border-collapse: collapse; }
        th, td { border: 1px solid #cbd5e1; padding: 8px; font-size: 13px; }
        th { background: #f1f5f9; text-align: left; }
        .right { text-align: right; font-weight: 700; }
        .footer { margin-top: 12px; color: #64748b; font-size: 12px; }
        @media print { .sheet { border: none; border-radius: 0; padding: 0; } }
    </style>
</head>
<body>
    <div class="sheet">
        <div class="brand">
            <div>
                <h1>NSTU Medical Center</h1>
                <p>Noakhali Science and Technology University</p>
            </div>
            <p>${_escapeHtml(paymentDate)}</p>
        </div>
        <div class="title">${_escapeHtml(title)}</div>
        <div class="meta">
            <div><strong>Patient:</strong> ${_escapeHtml(patientName)}</div>
            <div><strong>Mobile:</strong> ${_escapeHtml(mobile)}</div>
            <div><strong>Test:</strong> ${_escapeHtml(testName)}</div>
            <div><strong>Payment Method:</strong> ${_escapeHtml(paymentMethod)}</div>
            <div><strong>Transaction ID:</strong> ${_escapeHtml(transactionId)}</div>
            <div><strong>Payment Date:</strong> ${_escapeHtml(paymentDate)}</div>
        </div>
        <table>
            <thead>
                <tr><th>Description</th><th style="width: 180px;">Amount (৳)</th></tr>
            </thead>
            <tbody>
                <tr>
                    <td>${_escapeHtml(testName)} payment</td>
                    <td class="right">${amount.toStringAsFixed(2)}</td>
                </tr>
                <tr>
                    <td class="right"><strong>Total</strong></td>
                    <td class="right"><strong>${amount.toStringAsFixed(2)}</strong></td>
                </tr>
            </tbody>
        </table>
        <div class="footer">${_escapeHtml(footerNote)}</div>
    </div>
</body>
</html>
''';
}

String buildNstuLabReceiptHtml({
  required String title,
  required String patientName,
  required String mobile,
  required String invoiceNo,
  required String dateTime,
  required List<ReceiptLineItem> lines,
  String? barcodeSvg,
}) {
  final rows = lines
      .map(
        (line) =>
            '<tr><td>${_escapeHtml(line.code)}</td><td>${_escapeHtml(line.name)}</td><td>${_escapeHtml(line.extra.isEmpty ? '-' : line.extra)}</td><td>${_escapeHtml(line.type)}</td><td class="right">${line.amount.toStringAsFixed(2)}</td></tr>',
      )
      .join();
  final total = lines.fold<double>(0, (sum, line) => sum + line.amount);

  return '''
<!doctype html>
<html>
<head>
    <meta charset="utf-8" />
    <title>${_escapeHtml(title)}</title>
    <style>
        @page { margin: 14mm; }
        body { font-family: Arial, Helvetica, sans-serif; color: #0f172a; margin: 0; }
        .sheet { border: 1px solid #e2e8f0; border-radius: 12px; padding: 18px; }
        .brand { display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px; }
        .brand h1 { margin: 0; font-size: 22px; letter-spacing: .4px; }
        .brand p { margin: 0; color: #475569; font-size: 12px; }
        .meta { display: grid; grid-template-columns: 1fr 1fr; gap: 8px 20px; margin-bottom: 12px; }
        .meta div { font-size: 13px; }
        table { width: 100%; border-collapse: collapse; }
        th, td { border: 1px solid #cbd5e1; padding: 8px; font-size: 13px; }
        th { background: #f1f5f9; text-align: left; }
        .right { text-align: right; font-weight: 700; }
        .footer { margin-top: 12px; color: #64748b; font-size: 12px; }
        @media print { .sheet { border: none; border-radius: 0; padding: 0; } }
    </style>
</head>
<body>
    <div class="sheet">
        <div class="brand">
            <div>
                <h1>NSTU Medical Center</h1>
                <p>Noakhali Science and Technology University</p>
            </div>
            <p>${_escapeHtml(dateTime)}</p>
        </div>
        <div style="font-size:20px;font-weight:800;margin:8px 0 12px 0;">${_escapeHtml(title)}</div>
        <div class="meta">
            <div><strong>Patient:</strong> ${_escapeHtml(patientName)}</div>
            <div><strong>Mobile:</strong> ${_escapeHtml(mobile)}</div>
            <div><strong>Invoice:</strong> ${_escapeHtml(invoiceNo)}</div>
            <div><strong>Generated:</strong> ${_escapeHtml(dateTime)}</div>
        </div>
        ${barcodeSvg == null ? '' : '<div style="margin:8px 0 12px 0; border:1px solid #e2e8f0; border-radius:8px; padding:8px;">$barcodeSvg</div>'}
        <table>
            <thead>
                <tr><th>Code</th><th>Test Name</th><th>TAT</th><th>Type</th><th>Amount (৳)</th></tr>
            </thead>
            <tbody>
                $rows
                <tr>
                    <td colspan="4" class="right"><strong>Total Due</strong></td>
                    <td class="right"><strong>${total.toStringAsFixed(2)}</strong></td>
                </tr>
            </tbody>
        </table>
        <div class="footer">Printed from NSTU Medical Center lab upload portal.</div>
    </div>
</body>
</html>
''';
}

String _escapeHtml(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}
