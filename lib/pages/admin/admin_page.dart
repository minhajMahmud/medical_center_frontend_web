import 'package:backend_client/backend_client.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import 'package:universal_html/html.dart' as html;

import '../../controllers/role_dashboard_controller.dart';
import '../../utils/csv_exporter.dart';
import '../../widgets/common/dashboard_shell.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  _ReportRangePreset _reportRange = _ReportRangePreset.last90Days;
  DateTimeRange? _customRange;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<RoleDashboardController>().loadAdmin();
    });
  }

  void _downloadBytes({
    required List<int> bytes,
    required String fileName,
    required String mimeType,
  }) {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = fileName
      ..style.display = 'none';

    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }

  String _csvCell(String value) => '"${value.replaceAll('"', '""')}"';

  DateTimeRange get _effectiveRange {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    switch (_reportRange) {
      case _ReportRangePreset.last7Days:
        return DateTimeRange(
          start: end.subtract(const Duration(days: 6)),
          end: end,
        );
      case _ReportRangePreset.last30Days:
        return DateTimeRange(
          start: end.subtract(const Duration(days: 29)),
          end: end,
        );
      case _ReportRangePreset.last90Days:
        return DateTimeRange(
          start: end.subtract(const Duration(days: 89)),
          end: end,
        );
      case _ReportRangePreset.last365Days:
        return DateTimeRange(
          start: end.subtract(const Duration(days: 364)),
          end: end,
        );
      case _ReportRangePreset.custom:
        if (_customRange != null) {
          return DateTimeRange(
            start: DateTime(
              _customRange!.start.year,
              _customRange!.start.month,
              _customRange!.start.day,
              0,
              0,
              0,
            ),
            end: DateTime(
              _customRange!.end.year,
              _customRange!.end.month,
              _customRange!.end.day,
              23,
              59,
              59,
            ),
          );
        }
        return DateTimeRange(
          start: end.subtract(const Duration(days: 29)),
          end: end,
        );
    }
  }

  String get _selectedRangeLabel {
    switch (_reportRange) {
      case _ReportRangePreset.last7Days:
        return 'Last 7 days';
      case _ReportRangePreset.last30Days:
        return 'Last 30 days';
      case _ReportRangePreset.last90Days:
        return 'Last 90 days';
      case _ReportRangePreset.last365Days:
        return 'Last 12 months';
      case _ReportRangePreset.custom:
        if (_customRange == null) return 'Custom range';
        final df = DateFormat('dd MMM yyyy');
        return '${df.format(_customRange!.start)} - ${df.format(_customRange!.end)}';
    }
  }

  bool _withinRange(DateTime value) {
    final range = _effectiveRange;
    return !value.isBefore(range.start) && !value.isAfter(range.end);
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final initial =
        _customRange ??
        DateTimeRange(start: now.subtract(const Duration(days: 29)), end: now);

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: initial,
      helpText: 'Select report range',
    );

    if (picked == null) return;
    setState(() {
      _reportRange = _ReportRangePreset.custom;
      _customRange = picked;
    });
  }

  _AdminDashboardSnapshot _buildSnapshot(RoleDashboardController c) {
    final analytics = c.adminAnalytics;
    final overview = c.adminOverview;
    final now = DateTime.now();

    final monthlyRaw = [
      ...(analytics?.monthlyBreakdown ?? const <MonthlyBreakdown>[]),
    ]..sort((a, b) => a.month.compareTo(b.month));
    final monthly = monthlyRaw
        .where((m) => _withinRange(DateTime(now.year, m.month, 15, 12, 0, 0)))
        .toList();

    final audits =
        [...c.adminAudits].where((a) => _withinRange(a.createdAt)).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final topMedicines = [...(analytics?.topMedicines ?? const <TopMedicine>[])]
      ..sort((a, b) => b.used.compareTo(a.used));
    final stock = [...(analytics?.stockReport ?? const <StockReport>[])]
      ..sort((a, b) => a.current.compareTo(b.current));

    final totalPatients = analytics?.totalPatients ?? 0;
    final outPatients = analytics?.outPatients ?? 0;
    final totalPrescriptions = analytics?.totalPrescriptions ?? 0;
    final medicinesDispensed = analytics?.medicinesDispensed ?? 0;
    final totalUsers = overview?.totalUsers ?? 0;
    final totalStockItems = overview?.totalStockItems ?? 0;
    final doctorCount = analytics?.doctorCount ?? 0;
    final todayPrescriptions = analytics?.prescriptionStats.today ?? 0;
    final weekPrescriptions = analytics?.prescriptionStats.week ?? 0;
    final monthPrescriptions = analytics?.prescriptionStats.month ?? 0;
    final yearPrescriptions = analytics?.prescriptionStats.year ?? 0;

    final studentPatients = monthly.fold<int>(0, (sum, m) => sum + m.student);
    final teacherPatients = monthly.fold<int>(0, (sum, m) => sum + m.teacher);
    final outsideMonthlyPatients = monthly.fold<int>(
      0,
      (sum, m) => sum + m.outside,
    );
    final patientMixTotal =
        studentPatients + teacherPatients + outsideMonthlyPatients;

    final totalOpeningStock = stock.fold<int>(
      0,
      (sum, row) => sum + row.previous,
    );
    final totalCurrentStock = stock.fold<int>(
      0,
      (sum, row) => sum + row.current,
    );
    final totalUsedStock = stock.fold<int>(0, (sum, row) => sum + row.used);
    final usagePercent = totalOpeningStock == 0
        ? 0.0
        : (totalUsedStock / totalOpeningStock).clamp(0, 1).toDouble();
    final outPatientRatio = totalPatients == 0
        ? 0.0
        : (outPatients / totalPatients).clamp(0, 1).toDouble();
    final patientsPerDoctor = doctorCount == 0
        ? 0.0
        : totalPatients / doctorCount;

    final periodLabel = _selectedRangeLabel;

    return _AdminDashboardSnapshot(
      totalPatients: totalPatients,
      outPatients: outPatients,
      totalPrescriptions: totalPrescriptions,
      medicinesDispensed: medicinesDispensed,
      totalUsers: totalUsers,
      totalStockItems: totalStockItems,
      doctorCount: doctorCount,
      todayPrescriptions: todayPrescriptions,
      weekPrescriptions: weekPrescriptions,
      monthPrescriptions: monthPrescriptions,
      yearPrescriptions: yearPrescriptions,
      studentPatients: studentPatients,
      teacherPatients: teacherPatients,
      outsideMonthlyPatients: outsideMonthlyPatients,
      patientMixTotal: patientMixTotal,
      totalOpeningStock: totalOpeningStock,
      totalCurrentStock: totalCurrentStock,
      totalUsedStock: totalUsedStock,
      usagePercent: usagePercent,
      outPatientRatio: outPatientRatio,
      patientsPerDoctor: patientsPerDoctor,
      periodLabel: periodLabel,
      monthly: monthly,
      audits: audits,
      topMedicines: topMedicines,
      stock: stock,
    );
  }

  Future<void> _exportAdminPdf(RoleDashboardController c) async {
    final messenger = ScaffoldMessenger.of(context);
    final snapshot = _buildSnapshot(c);

    try {
      final doc = pw.Document();
      final fileDate = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final generatedLabel = DateFormat(
        'dd MMM yyyy, hh:mm a',
      ).format(DateTime.now());
      final logoBytes = (await rootBundle.load(
        'assets/images/nstu_logo.jpg',
      )).buffer.asUint8List();
      final logo = pw.MemoryImage(logoBytes);

      pw.Widget buildMetricCard(String label, String value, String note) {
        return pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F8FAFC'),
              border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  label,
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColor.fromHex('#64748B'),
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  value,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#0F172A'),
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  note,
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: PdfColor.fromHex('#64748B'),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      pw.Widget buildSectionTitle(String title, String subtitle) {
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 15,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#0F172A'),
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                subtitle,
                style: pw.TextStyle(
                  fontSize: 9,
                  color: PdfColor.fromHex('#64748B'),
                ),
              ),
            ],
          ),
        );
      }

      doc.addPage(
        pw.MultiPage(
          pageTheme: pw.PageTheme(
            margin: const pw.EdgeInsets.all(28),
            theme: pw.ThemeData.withFont(
              base: pw.Font.helvetica(),
              bold: pw.Font.helveticaBold(),
            ),
          ),
          build: (_) => [
            pw.Container(
              padding: const pw.EdgeInsets.all(18),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#0F766E'),
                borderRadius: pw.BorderRadius.circular(14),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 74,
                    height: 74,
                    padding: const pw.EdgeInsets.all(6),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(12),
                    ),
                    child: pw.Image(logo, fit: pw.BoxFit.contain),
                  ),
                  pw.SizedBox(width: 16),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'NSTU Medical Center',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Admin Enterprise Overview Report',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 16,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          'Generated: $generatedLabel',
                          style: pw.TextStyle(
                            color: PdfColor.fromHex('#D1FAE5'),
                            fontSize: 11,
                          ),
                        ),
                        pw.Text(
                          'Reporting period: ${snapshot.periodLabel}',
                          style: pw.TextStyle(
                            color: PdfColor.fromHex('#CCFBF1'),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Row(
              children: [
                buildMetricCard(
                  'Total Patients',
                  _formatCompact(snapshot.totalPatients),
                  '${(snapshot.outPatientRatio * 100).round()}% outside patients',
                ),
                pw.SizedBox(width: 10),
                buildMetricCard(
                  'Prescriptions',
                  _formatCompact(snapshot.totalPrescriptions),
                  '${snapshot.todayPrescriptions} today · ${snapshot.weekPrescriptions} this week',
                ),
                pw.SizedBox(width: 10),
                buildMetricCard(
                  'Medicines Dispensed',
                  _formatCompact(snapshot.medicinesDispensed),
                  '${snapshot.monthPrescriptions} this month',
                ),
                pw.SizedBox(width: 10),
                buildMetricCard(
                  'System Footprint',
                  '${snapshot.totalUsers} users',
                  '${snapshot.totalStockItems} inventory items',
                ),
              ],
            ),
            pw.SizedBox(height: 18),
            buildSectionTitle(
              'Operational Mix',
              'Patient composition, staff coverage, and stock efficiency derived from current analytics.',
            ),
            pw.Row(
              children: [
                buildMetricCard(
                  'Students',
                  snapshot.studentPatients.toString(),
                  _percentLabel(
                    snapshot.studentPatients,
                    snapshot.patientMixTotal,
                  ),
                ),
                pw.SizedBox(width: 10),
                buildMetricCard(
                  'Teachers',
                  snapshot.teacherPatients.toString(),
                  _percentLabel(
                    snapshot.teacherPatients,
                    snapshot.patientMixTotal,
                  ),
                ),
                pw.SizedBox(width: 10),
                buildMetricCard(
                  'Outside Patients',
                  snapshot.outsideMonthlyPatients.toString(),
                  _percentLabel(
                    snapshot.outsideMonthlyPatients,
                    snapshot.patientMixTotal,
                  ),
                ),
                pw.SizedBox(width: 10),
                buildMetricCard(
                  'Staff Efficiency',
                  snapshot.doctorCount == 0
                      ? 'N/A'
                      : snapshot.patientsPerDoctor.toStringAsFixed(1),
                  '${snapshot.doctorCount} doctors covering patient load',
                ),
              ],
            ),
            pw.SizedBox(height: 18),
            buildSectionTitle(
              'Monthly Visit Breakdown',
              'Distribution of total visits by month, with student, teacher, and outside patient counts.',
            ),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
                color: PdfColor.fromHex('#334155'),
              ),
              headerDecoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F8FAFC'),
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 6,
              ),
              border: pw.TableBorder.all(
                color: PdfColor.fromHex('#E2E8F0'),
                width: 0.6,
              ),
              headers: const [
                'Month',
                'Total',
                'Students',
                'Teachers',
                'Outside',
                'Revenue',
              ],
              data: snapshot.monthly.isEmpty
                  ? [
                      const ['N/A', '0', '0', '0', '0', '0.00'],
                    ]
                  : snapshot.monthly
                        .map(
                          (m) => [
                            DateFormat(
                              'MMM',
                            ).format(DateTime(DateTime.now().year, m.month)),
                            m.total.toString(),
                            m.student.toString(),
                            m.teacher.toString(),
                            m.outside.toString(),
                            m.revenue.toStringAsFixed(2),
                          ],
                        )
                        .toList(),
            ),
            pw.SizedBox(height: 18),
            buildSectionTitle(
              'Medicine and Stock Insights',
              'Top-used medicines and current critical stock levels from the latest inventory analytics.',
            ),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Top Medicines',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#0F172A'),
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.TableHelper.fromTextArray(
                        headerStyle: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 9,
                          color: PdfColor.fromHex('#334155'),
                        ),
                        headerDecoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('#F8FAFC'),
                        ),
                        cellStyle: const pw.TextStyle(fontSize: 9),
                        border: pw.TableBorder.all(
                          color: PdfColor.fromHex('#E2E8F0'),
                          width: 0.6,
                        ),
                        headers: const ['Medicine', 'Used'],
                        data: snapshot.topMedicines.isEmpty
                            ? [
                                const ['No data', '0'],
                              ]
                            : snapshot.topMedicines
                                  .take(8)
                                  .map(
                                    (m) => [m.medicineName, m.used.toString()],
                                  )
                                  .toList(),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Critical Stock Levels',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#0F172A'),
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.TableHelper.fromTextArray(
                        headerStyle: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 9,
                          color: PdfColor.fromHex('#334155'),
                        ),
                        headerDecoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('#F8FAFC'),
                        ),
                        cellStyle: const pw.TextStyle(fontSize: 9),
                        border: pw.TableBorder.all(
                          color: PdfColor.fromHex('#E2E8F0'),
                          width: 0.6,
                        ),
                        headers: const ['Item', 'Opening', 'Current', 'Used'],
                        data: snapshot.stock.isEmpty
                            ? [
                                const ['No data', '0', '0', '0'],
                              ]
                            : snapshot.stock
                                  .take(8)
                                  .map(
                                    (s) => [
                                      s.itemName,
                                      s.previous.toString(),
                                      s.current.toString(),
                                      s.used.toString(),
                                    ],
                                  )
                                  .toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 18),
            buildSectionTitle(
              'Recent Audit Activity',
              'Latest admin-side actions captured by the audit log.',
            ),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
                color: PdfColor.fromHex('#334155'),
              ),
              headerDecoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F8FAFC'),
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              border: pw.TableBorder.all(
                color: PdfColor.fromHex('#E2E8F0'),
                width: 0.6,
              ),
              headers: const ['Action', 'Actor', 'Target', 'Time'],
              data: snapshot.audits.isEmpty
                  ? [
                      const ['No recent activity', '-', '-', '-'],
                    ]
                  : snapshot.audits
                        .take(10)
                        .map(
                          (a) => [
                            a.action,
                            (a.adminName ?? '-').toString(),
                            (a.targetName ?? '-').toString(),
                            DateFormat('dd MMM, hh:mm a').format(a.createdAt),
                          ],
                        )
                        .toList(),
            ),
          ],
        ),
      );

      final bytes = await doc.save();
      _downloadBytes(
        bytes: bytes,
        fileName: 'admin_enterprise_report_$fileDate.pdf',
        mimeType: 'application/pdf',
      );

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Admin report PDF exported successfully.'),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to export admin report PDF: $e')),
      );
    }
  }

  Future<void> _exportAdminCsv(RoleDashboardController c) async {
    final messenger = ScaffoldMessenger.of(context);
    final snapshot = _buildSnapshot(c);

    try {
      final fileDate = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final rows = <List<String>>[
        const ['NSTU Medical Center - Admin Enterprise Overview Report'],
        [
          'Generated',
          DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
        ],
        ['Reporting Period', snapshot.periodLabel],
        const [],
        const ['Summary Metrics'],
        ['Total Patients', snapshot.totalPatients.toString()],
        ['Outside Patients', snapshot.outPatients.toString()],
        ['Total Prescriptions', snapshot.totalPrescriptions.toString()],
        ['Medicines Dispensed', snapshot.medicinesDispensed.toString()],
        ['Total Users', snapshot.totalUsers.toString()],
        ['Total Stock Items', snapshot.totalStockItems.toString()],
        ['Doctors', snapshot.doctorCount.toString()],
        ['Today Prescriptions', snapshot.todayPrescriptions.toString()],
        ['Week Prescriptions', snapshot.weekPrescriptions.toString()],
        ['Month Prescriptions', snapshot.monthPrescriptions.toString()],
        ['Year Prescriptions', snapshot.yearPrescriptions.toString()],
        const [],
        const [
          'Monthly Breakdown',
          'Month',
          'Total',
          'Students',
          'Teachers',
          'Outside',
          'Revenue',
        ],
        ...snapshot.monthly.map(
          (m) => [
            '',
            DateFormat('MMM').format(DateTime(DateTime.now().year, m.month)),
            m.total.toString(),
            m.student.toString(),
            m.teacher.toString(),
            m.outside.toString(),
            m.revenue.toStringAsFixed(2),
          ],
        ),
        const [],
        const ['Top Medicines', 'Medicine', 'Used'],
        ...snapshot.topMedicines.map(
          (m) => ['', m.medicineName, m.used.toString()],
        ),
        const [],
        const ['Stock Insights', 'Item', 'Opening', 'Current', 'Used'],
        ...snapshot.stock.map(
          (s) => [
            '',
            s.itemName,
            s.previous.toString(),
            s.current.toString(),
            s.used.toString(),
          ],
        ),
        const [],
        const ['Recent Audits', 'Action', 'Actor', 'Target', 'Time'],
        ...snapshot.audits.map(
          (a) => [
            '',
            a.action,
            (a.adminName ?? '-').toString(),
            (a.targetName ?? '-').toString(),
            DateFormat('dd MMM, hh:mm a').format(a.createdAt),
          ],
        ),
      ];

      final csv = rows.map((row) => row.map(_csvCell).join(',')).join('\n');

      await exportCsvFile(
        fileName: 'admin_enterprise_report_$fileDate.csv',
        csvContent: csv,
      );

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Admin report CSV exported successfully.'),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to export admin report CSV: $e')),
      );
    }
  }

  Future<void> _showFullAuditLog(List<AuditEntry> audits) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 20,
          ),
          child: Container(
            width: 960,
            constraints: const BoxConstraints(maxHeight: 680),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Full Audit Log',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Showing ${audits.length} recorded admin actions.',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                if (audits.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text(
                        'No audit entries found.',
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: SingleChildScrollView(
                      child: DataTable(
                        columnSpacing: 24,
                        headingTextStyle: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF475569),
                        ),
                        dataTextStyle: const TextStyle(
                          color: Color(0xFF0F172A),
                        ),
                        columns: const [
                          DataColumn(label: Text('Action')),
                          DataColumn(label: Text('Actor')),
                          DataColumn(label: Text('Target')),
                          DataColumn(label: Text('Time')),
                        ],
                        rows: audits
                            .map(
                              (a) => DataRow(
                                cells: [
                                  DataCell(Text(a.action)),
                                  DataCell(
                                    Text((a.adminName ?? '-').toString()),
                                  ),
                                  DataCell(
                                    Text((a.targetName ?? '-').toString()),
                                  ),
                                  DataCell(
                                    Text(
                                      DateFormat(
                                        'dd MMM yyyy, hh:mm a',
                                      ).format(a.createdAt),
                                    ),
                                  ),
                                ],
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<RoleDashboardController>();
    final snapshot = _buildSnapshot(c);

    return DashboardShell(
      child: c.isLoading && c.adminAnalytics == null && c.adminOverview == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _HeroHeader(
                  periodLabel: snapshot.periodLabel,
                  onExport: () => _exportAdminPdf(c),
                  onExportCsv: () => _exportAdminCsv(c),
                ),
                const SizedBox(height: 12),
                _RangeSelectorBar(
                  selected: _reportRange,
                  currentLabel: _selectedRangeLabel,
                  onSelect: (preset) {
                    setState(() => _reportRange = preset);
                  },
                  onCustomPick: _pickCustomRange,
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _AdminKpiCard(
                      icon: Icons.groups_rounded,
                      iconColor: const Color(0xFF2563EB),
                      iconBackground: const Color(0xFFEFF6FF),
                      title: 'Total Patients',
                      value: _formatCompact(snapshot.totalPatients),
                      badgeText:
                          '${(snapshot.outPatientRatio * 100).round()}% outside',
                      badgeColor: const Color(0xFF16A34A),
                      footerLabel:
                          '${snapshot.totalUsers} active users on panel',
                      bars: const [0.44, 0.62, 0.48, 0.72, 0.86],
                    ),
                    _AdminKpiCard(
                      icon: Icons.medication_liquid_rounded,
                      iconColor: const Color(0xFF0D9488),
                      iconBackground: const Color(0xFFF0FDFA),
                      title: 'Medicines Dispensed',
                      value: _formatCompact(snapshot.medicinesDispensed),
                      badgeText: '${snapshot.todayPrescriptions} today',
                      badgeColor: const Color(0xFF14B8A6),
                      footerLabel:
                          '${snapshot.totalUsedStock} stock units used so far',
                      bars: const [0.25, 0.29, 0.52, 0.41, 0.34],
                    ),
                    _AdminKpiCard(
                      icon: Icons.receipt_long_rounded,
                      iconColor: const Color(0xFFEA580C),
                      iconBackground: const Color(0xFFFFF7ED),
                      title: 'Prescriptions',
                      value: _formatCompact(snapshot.totalPrescriptions),
                      badgeText: '${snapshot.weekPrescriptions} this week',
                      badgeColor: const Color(0xFFEA580C),
                      footerLabel:
                          '${snapshot.monthPrescriptions} this month · ${snapshot.yearPrescriptions} this year',
                      bars: const [0.12, 0.18, 0.15, 0.24, 0.31],
                    ),
                    _AdminKpiCard(
                      icon: Icons.inventory_2_rounded,
                      iconColor: const Color(0xFF7C3AED),
                      iconBackground: const Color(0xFFF5F3FF),
                      title: 'Inventory Coverage',
                      value: '${snapshot.totalStockItems} items',
                      badgeText:
                          '${(snapshot.usagePercent * 100).round()}% used',
                      badgeColor: const Color(0xFF7C3AED),
                      footerLabel:
                          '${snapshot.totalCurrentStock} units currently in store',
                      bars: const [0.78, 0.66, 0.58, 0.46, 0.39],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < 1180;

                    final overviewColumn = Column(
                      children: [
                        _MonthlyOverviewCard(snapshot: snapshot),
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _PatientMixCard(snapshot: snapshot),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _CriticalStockCard(stock: snapshot.stock),
                            ),
                          ],
                        ),
                      ],
                    );

                    final sideColumn = Column(
                      children: [
                        _ActivityFeedCard(
                          audits: snapshot.audits,
                          onViewAll: () => _showFullAuditLog(snapshot.audits),
                        ),
                        const SizedBox(height: 14),
                        _EfficiencyCard(snapshot: snapshot),
                        const SizedBox(height: 14),
                        _TopMedicinesCard(topMedicines: snapshot.topMedicines),
                      ],
                    );

                    if (stacked) {
                      return Column(
                        children: [
                          overviewColumn,
                          const SizedBox(height: 14),
                          sideColumn,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 5, child: overviewColumn),
                        const SizedBox(width: 14),
                        Expanded(flex: 2, child: sideColumn),
                      ],
                    );
                  },
                ),
              ],
            ),
    );
  }

  static String _formatCompact(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toString();
  }

  static String _percentLabel(int value, int total) {
    if (total == 0) return '0% of patient mix';
    final pct = ((value / total) * 100).round();
    return '$pct% of patient mix';
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.periodLabel,
    required this.onExport,
    required this.onExportCsv,
  });

  final String periodLabel;
  final VoidCallback onExport;
  final VoidCallback onExportCsv;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF115E59), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A0F172A),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enterprise Overview',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Professional admin reporting for patient activity, prescription operations, stock movement, and audit visibility.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.84),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _TopChip(icon: Icons.calendar_today_rounded, label: periodLabel),
              const SizedBox(height: 10),
              _TopChip(
                icon: Icons.verified_user_outlined,
                label: 'Admin analytics live',
              ),
            ],
          ),
          const SizedBox(width: 14),
          FilledButton.icon(
            onPressed: onExport,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0F172A),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Export Report'),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: onExportCsv,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.table_view_rounded, size: 18),
            label: const Text('Export CSV'),
          ),
        ],
      ),
    );
  }
}

class _TopChip extends StatelessWidget {
  const _TopChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminKpiCard extends StatelessWidget {
  const _AdminKpiCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.value,
    required this.badgeText,
    required this.badgeColor,
    required this.footerLabel,
    required this.bars,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String value;
  final String badgeText;
  final Color badgeColor;
  final String footerLabel;
  final List<double> bars;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 290),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A020617),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 28,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: bars
                    .map(
                      (bar) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Container(
                            height: 8 + (20 * bar),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: iconColor.withValues(
                                alpha: 0.24 + (bar * 0.5),
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              footerLabel,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthlyOverviewCard extends StatelessWidget {
  const _MonthlyOverviewCard({required this.snapshot});

  final _AdminDashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final values = snapshot.monthly.isEmpty
        ? [
            const _ChartMonthPoint(
              label: 'Jan',
              total: 0,
              students: 0,
              teachers: 0,
              outside: 0,
            ),
            const _ChartMonthPoint(
              label: 'Feb',
              total: 0,
              students: 0,
              teachers: 0,
              outside: 0,
            ),
            const _ChartMonthPoint(
              label: 'Mar',
              total: 0,
              students: 0,
              teachers: 0,
              outside: 0,
            ),
          ]
        : snapshot.monthly
              .map(
                (m) => _ChartMonthPoint(
                  label: DateFormat(
                    'MMM',
                  ).format(DateTime(DateTime.now().year, m.month)),
                  total: m.total,
                  students: m.student,
                  teachers: m.teacher,
                  outside: m.outside,
                ),
              )
              .toList();

    final maxY =
        values
            .map((e) => e.total)
            .fold<int>(0, (max, value) => value > max ? value : max)
            .toDouble() +
        10;

    return _GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lab Test Volumes & Patient Visits',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'A cleaner executive view of monthly patient demand, split by internal and external patient groups.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const _MiniModeChip(label: 'CHART', selected: true),
              const SizedBox(width: 8),
              const _MiniModeChip(label: 'DATA'),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 280,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY <= 0 ? 10 : maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxY <= 0 ? 10 : maxY) / 4,
                  getDrawingHorizontalLine: (_) =>
                      const FlLine(color: Color(0xFFEAEFF5), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      interval: (maxY <= 0 ? 10 : maxY) / 4,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= values.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            values[index].label,
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF0F172A),
                    getTooltipItems: (spots) => spots
                        .map(
                          (spot) => LineTooltipItem(
                            '${values[spot.x.toInt()].label}\n${spot.y.toInt()} visits',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < values.length; i++)
                        FlSpot(i.toDouble(), values[i].total.toDouble()),
                    ],
                    isCurved: true,
                    color: const Color(0xFF1D4ED8),
                    barWidth: 3.2,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF3B82F6).withValues(alpha: 0.22),
                          const Color(0xFF3B82F6).withValues(alpha: 0.03),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _LegendStat(
                color: const Color(0xFF2563EB),
                label: 'Total Visits',
                value: snapshot.totalPatients.toString(),
              ),
              _LegendStat(
                color: const Color(0xFF14B8A6),
                label: 'Students',
                value: snapshot.studentPatients.toString(),
              ),
              _LegendStat(
                color: const Color(0xFFF97316),
                label: 'Outside Patients',
                value: snapshot.outsideMonthlyPatients.toString(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniModeChip extends StatelessWidget {
  const _MiniModeChip({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFE6FFFB) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? const Color(0xFF99F6E4) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? const Color(0xFF0F766E) : const Color(0xFF64748B),
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _PatientMixCard extends StatelessWidget {
  const _PatientMixCard({required this.snapshot});

  final _AdminDashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final total = snapshot.patientMixTotal;
    final sections = <_MixSlice>[
      _MixSlice(
        label: 'Students',
        value: snapshot.studentPatients,
        color: const Color(0xFF2563EB),
      ),
      _MixSlice(
        label: 'Teachers',
        value: snapshot.teacherPatients,
        color: const Color(0xFF10B981),
      ),
      _MixSlice(
        label: 'Outside',
        value: snapshot.outsideMonthlyPatients,
        color: const Color(0xFFF97316),
      ),
    ];

    return _GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Patient Composition',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Distribution of patient demand by audience segment from available monthly records.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 170,
                height: 170,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        centerSpaceRadius: 46,
                        sectionsSpace: 2,
                        startDegreeOffset: -90,
                        sections: sections
                            .map(
                              (slice) => PieChartSectionData(
                                value: slice.value <= 0
                                    ? 0.01
                                    : slice.value.toDouble(),
                                color: slice.color,
                                radius: 16,
                                showTitle: false,
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          total.toString(),
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'CASES',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.7,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  children: sections
                      .map(
                        (slice) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _MixLegendRow(slice: slice, total: total),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CriticalStockCard extends StatelessWidget {
  const _CriticalStockCard({required this.stock});

  final List<StockReport> stock;

  @override
  Widget build(BuildContext context) {
    final items = stock.take(5).toList();

    return _GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Critical Stock Levels',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6FFFB),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'REORDER',
                  style: TextStyle(
                    color: Color(0xFF0F766E),
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            const Text(
              'No stock analytics available yet.',
              style: TextStyle(color: Color(0xFF64748B)),
            )
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _CriticalStockRow(item: item),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActivityFeedCard extends StatelessWidget {
  const _ActivityFeedCard({required this.audits, required this.onViewAll});

  final List<AuditEntry> audits;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final rows = audits.take(5).toList();

    return _GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Real-time Activity',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (rows.isEmpty)
            const Text(
              'No recent audit activity available.',
              style: TextStyle(color: Color(0xFF64748B)),
            )
          else
            ...rows.map(
              (audit) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _ActivityRow(audit: audit),
              ),
            ),
          const SizedBox(height: 6),
          OutlinedButton(
            onPressed: onViewAll,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('View Full Audit Log'),
          ),
        ],
      ),
    );
  }
}

class _EfficiencyCard extends StatelessWidget {
  const _EfficiencyCard({required this.snapshot});

  final _AdminDashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Staff Efficiency',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.medical_services_rounded,
                    color: Color(0xFF0369A1),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Doctors',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  snapshot.doctorCount.toString(),
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              snapshot.doctorCount == 0
                  ? 'No doctor ratio available'
                  : 'Ratio 1:${snapshot.patientsPerDoctor.toStringAsFixed(1)} patients',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopMedicinesCard extends StatelessWidget {
  const _TopMedicinesCard({required this.topMedicines});

  final List<TopMedicine> topMedicines;

  @override
  Widget build(BuildContext context) {
    final maxValue = topMedicines.isEmpty
        ? 1
        : topMedicines.map((m) => m.used).reduce((a, b) => a > b ? a : b);

    return _GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Prescription Activity',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Most-used medicines from the current reporting range.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
          const SizedBox(height: 14),
          if (topMedicines.isEmpty)
            const Text(
              'No medicine usage data available.',
              style: TextStyle(color: Color(0xFF64748B)),
            )
          else
            ...topMedicines
                .take(4)
                .map(
                  (medicine) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _UsageProgressRow(
                      label: medicine.medicineName,
                      value: medicine.used,
                      ratio: (medicine.used / maxValue).clamp(0, 1).toDouble(),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _LegendStat extends StatelessWidget {
  const _LegendStat({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _MixLegendRow extends StatelessWidget {
  const _MixLegendRow({required this.slice, required this.total});

  final _MixSlice slice;
  final int total;

  @override
  Widget build(BuildContext context) {
    final percent = total == 0 ? 0 : ((slice.value / total) * 100).round();

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: slice.color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            slice.label,
            style: const TextStyle(
              color: Color(0xFF334155),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          '$percent%',
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _CriticalStockRow extends StatelessWidget {
  const _CriticalStockRow({required this.item});

  final StockReport item;

  @override
  Widget build(BuildContext context) {
    final status = item.current <= 5
        ? const _StockStatus('Critical', Color(0xFFDC2626), Color(0xFFFEF2F2))
        : item.current <= 20
        ? const _StockStatus('Low Stock', Color(0xFFEA580C), Color(0xFFFFF7ED))
        : const _StockStatus('In Stock', Color(0xFF16A34A), Color(0xFFF0FDF4));

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.itemName,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                'Opening ${item.previous} · Used ${item.used}',
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: status.background,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            status.label.toUpperCase(),
            style: TextStyle(
              color: status.foreground,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          item.current.toString(),
          style: TextStyle(
            color: status.foreground,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.audit});

  final AuditEntry audit;

  @override
  Widget build(BuildContext context) {
    final activity = _activityStyle(audit.action);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: activity.background,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(activity.icon, color: activity.color, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                audit.action,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                [
                  audit.adminName ?? 'Admin user',
                  audit.targetName ?? 'System',
                ].where((e) => e.trim().isNotEmpty).join(' · '),
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat('dd MMM, hh:mm a').format(audit.createdAt),
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static _ActivityStyle _activityStyle(String action) {
    final value = action.toLowerCase();
    if (value.contains('delete') || value.contains('reject')) {
      return const _ActivityStyle(
        icon: Icons.warning_rounded,
        color: Color(0xFFEA580C),
        background: Color(0xFFFFF7ED),
      );
    }
    if (value.contains('stock') || value.contains('inventory')) {
      return const _ActivityStyle(
        icon: Icons.inventory_2_rounded,
        color: Color(0xFF0F766E),
        background: Color(0xFFF0FDFA),
      );
    }
    if (value.contains('patient') || value.contains('appointment')) {
      return const _ActivityStyle(
        icon: Icons.person_add_alt_1_rounded,
        color: Color(0xFF2563EB),
        background: Color(0xFFEFF6FF),
      );
    }
    return const _ActivityStyle(
      icon: Icons.description_rounded,
      color: Color(0xFF6366F1),
      background: Color(0xFFEEF2FF),
    );
  }
}

class _UsageProgressRow extends StatelessWidget {
  const _UsageProgressRow({
    required this.label,
    required this.value,
    required this.ratio,
  });

  final String label;
  final int value;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF334155),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              value.toString(),
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 7,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
          ),
        ),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A020617),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

enum _ReportRangePreset {
  last7Days,
  last30Days,
  last90Days,
  last365Days,
  custom,
}

class _RangeSelectorBar extends StatelessWidget {
  const _RangeSelectorBar({
    required this.selected,
    required this.currentLabel,
    required this.onSelect,
    required this.onCustomPick,
  });

  final _ReportRangePreset selected;
  final String currentLabel;
  final ValueChanged<_ReportRangePreset> onSelect;
  final VoidCallback onCustomPick;

  @override
  Widget build(BuildContext context) {
    Widget chip({required String label, required _ReportRangePreset value}) {
      final isSelected = selected == value;
      return ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onSelect(value),
        labelStyle: TextStyle(
          color: isSelected ? const Color(0xFF0F766E) : const Color(0xFF64748B),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        selectedColor: const Color(0xFFE6FFFB),
        backgroundColor: Colors.white,
        side: BorderSide(
          color: isSelected ? const Color(0xFF99F6E4) : const Color(0xFFE2E8F0),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Report window:',
              style: TextStyle(
                color: Color(0xFF475569),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          chip(label: '7D', value: _ReportRangePreset.last7Days),
          chip(label: '30D', value: _ReportRangePreset.last30Days),
          chip(label: '90D', value: _ReportRangePreset.last90Days),
          chip(label: '12M', value: _ReportRangePreset.last365Days),
          chip(label: 'Custom', value: _ReportRangePreset.custom),
          if (selected == _ReportRangePreset.custom)
            OutlinedButton.icon(
              onPressed: onCustomPick,
              icon: const Icon(Icons.date_range_rounded, size: 16),
              label: const Text('Pick Range'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF99F6E4)),
                foregroundColor: const Color(0xFF0F766E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              currentLabel,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminDashboardSnapshot {
  const _AdminDashboardSnapshot({
    required this.totalPatients,
    required this.outPatients,
    required this.totalPrescriptions,
    required this.medicinesDispensed,
    required this.totalUsers,
    required this.totalStockItems,
    required this.doctorCount,
    required this.todayPrescriptions,
    required this.weekPrescriptions,
    required this.monthPrescriptions,
    required this.yearPrescriptions,
    required this.studentPatients,
    required this.teacherPatients,
    required this.outsideMonthlyPatients,
    required this.patientMixTotal,
    required this.totalOpeningStock,
    required this.totalCurrentStock,
    required this.totalUsedStock,
    required this.usagePercent,
    required this.outPatientRatio,
    required this.patientsPerDoctor,
    required this.periodLabel,
    required this.monthly,
    required this.audits,
    required this.topMedicines,
    required this.stock,
  });

  final int totalPatients;
  final int outPatients;
  final int totalPrescriptions;
  final int medicinesDispensed;
  final int totalUsers;
  final int totalStockItems;
  final int doctorCount;
  final int todayPrescriptions;
  final int weekPrescriptions;
  final int monthPrescriptions;
  final int yearPrescriptions;
  final int studentPatients;
  final int teacherPatients;
  final int outsideMonthlyPatients;
  final int patientMixTotal;
  final int totalOpeningStock;
  final int totalCurrentStock;
  final int totalUsedStock;
  final double usagePercent;
  final double outPatientRatio;
  final double patientsPerDoctor;
  final String periodLabel;
  final List<MonthlyBreakdown> monthly;
  final List<AuditEntry> audits;
  final List<TopMedicine> topMedicines;
  final List<StockReport> stock;
}

class _ChartMonthPoint {
  const _ChartMonthPoint({
    required this.label,
    required this.total,
    required this.students,
    required this.teachers,
    required this.outside,
  });

  final String label;
  final int total;
  final int students;
  final int teachers;
  final int outside;
}

class _MixSlice {
  const _MixSlice({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;
}

class _StockStatus {
  const _StockStatus(this.label, this.foreground, this.background);

  final String label;
  final Color foreground;
  final Color background;
}

class _ActivityStyle {
  const _ActivityStyle({
    required this.icon,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final Color color;
  final Color background;
}
