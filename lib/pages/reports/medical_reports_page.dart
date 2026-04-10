import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:typed_data';
import 'package:backend_client/backend_client.dart';

import '../../controllers/role_dashboard_controller.dart';
import '../../utils/prescription_pdf_service.dart';
import '../../utils/receipt_print_service.dart';
import '../../widgets/common/dashboard_shell.dart';

class MedicalReportsPage extends StatefulWidget {
  const MedicalReportsPage({super.key});

  @override
  State<MedicalReportsPage> createState() => _MedicalReportsPageState();
}

class _MedicalReportsPageState extends State<MedicalReportsPage> {
  static const _surface = Color(0xFFFFFFFF);
  static const _pageBg = Color(0xFFF8FAFC);
  static const _border = Color(0xFFE2E8F0);
  static const _headerBg = Color(0xFFF1F5F9);
  static const _textMuted = Color(0xFF64748B);
  static const _primary = Color(0xFF2563EB);

  final TextEditingController _searchCtrl = TextEditingController();
  int _page = 0;
  static const int _pageSize = 5;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final c = context.read<RoleDashboardController>();
      c.loadPatient();
    });

    _searchCtrl.addListener(() {
      if (!mounted) return;
      setState(() {
        _page = 0;
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _safeFileName(PatientReportDto report) {
    final date = DateFormat('yyyyMMdd').format(report.date.toLocal());
    final base = '${report.testName}_$date';
    return base.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
  }

  String _safePrescriptionFileName(PrescriptionList prescription) {
    final date = DateFormat('yyyyMMdd').format(prescription.date.toLocal());
    final base = 'prescription_${prescription.prescriptionId}_$date';
    return base.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
  }

  bool _isPdfUrl(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.pdf') || lower.contains('.pdf?');
  }

  Future<String?> _createPdfObjectUrl(String src) async {
    try {
      final response = await html.HttpRequest.request(
        src,
        method: 'GET',
        responseType: 'arraybuffer',
      );
      final raw = response.response;
      if (raw is! ByteBuffer) return null;
      final bytes = Uint8List.view(raw);
      final blob = html.Blob(<dynamic>[bytes], 'application/pdf');
      return html.Url.createObjectUrlFromBlob(blob);
    } catch (_) {
      return null;
    }
  }

  Future<void> _openReport(PatientReportDto report) async {
    final url = report.fileUrl?.trim();
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report file is not uploaded yet.')),
      );
      return;
    }
    var viewUrl = url;
    if (_isPdfUrl(url)) {
      final objectUrl = await _createPdfObjectUrl(url);
      if (objectUrl != null) {
        viewUrl = objectUrl;
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Direct PDF preview unavailable. Opening original file instead.',
            ),
          ),
        );
      }
    }
    html.window.open(viewUrl, '_blank');
  }

  void _downloadReport(PatientReportDto report) {
    final url = report.fileUrl?.trim();
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report file is not uploaded yet.')),
      );
      return;
    }

    try {
      final anchor = html.AnchorElement(href: url)
        ..download = _safeFileName(report)
        ..style.display = 'none';
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
    } catch (_) {
      html.window.open(url, '_blank');
    }
  }

  void _downloadAll(List<PatientReportDto> reports) {
    final uploaded = reports
        .where((r) => r.isUploaded && (r.fileUrl?.trim().isNotEmpty ?? false))
        .toList();

    if (uploaded.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No uploaded reports available.')),
      );
      return;
    }

    for (final report in uploaded) {
      _downloadReport(report);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Downloading ${uploaded.length} report(s)...')),
    );
  }

  List<PatientReportDto> _filtered(List<PatientReportDto> reports) {
    final q = _searchCtrl.text.trim().toLowerCase();
    return reports.where((r) {
      final queryMatches =
          q.isEmpty ||
          r.testName.toLowerCase().contains(q) ||
          r.id.toString().contains(q);
      return queryMatches;
    }).toList();
  }

  List<PrescriptionList> _filteredPrescriptions(
    List<PrescriptionList> prescriptions,
  ) {
    final q = _searchCtrl.text.trim().toLowerCase();
    return prescriptions.where((p) {
      final queryMatches =
          q.isEmpty ||
          p.doctorName.toLowerCase().contains(q) ||
          p.prescriptionId.toString().contains(q);
      return queryMatches;
    }).toList();
  }

  Future<void> _viewPrescription(PrescriptionList prescription) async {
    final c = context.read<RoleDashboardController>();
    final details = await c.loadPatientPrescriptionDetails(
      prescription.prescriptionId,
    );
    if (!mounted) return;

    if (details == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(c.error ?? 'Failed to load prescription details.'),
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Prescription #${prescription.prescriptionId}'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Doctor: ${details.doctorName ?? prescription.doctorName}',
                ),
                const SizedBox(height: 4),
                Text(
                  'Date: ${DateFormat('dd MMM yyyy').format((details.prescription.prescriptionDate ?? prescription.date).toLocal())}',
                ),
                const SizedBox(height: 10),
                Text('Diagnosis: ${details.prescription.cc ?? '-'}'),
                const SizedBox(height: 6),
                Text('Advice: ${details.prescription.advice ?? '-'}'),
                const SizedBox(height: 6),
                Text('Tests: ${details.prescription.test ?? '-'}'),
                const SizedBox(height: 12),
                const Text(
                  'Medicines',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                if (details.items.isEmpty)
                  const Text('No medicines found.')
                else
                  ...details.items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '• ${item.medicineName}  |  ${item.dosageTimes ?? '-'}  |  ${item.mealTiming ?? '-'}  |  ${item.duration?.toString() ?? '-'} day(s)',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadPrescription(PrescriptionList prescription) async {
    final c = context.read<RoleDashboardController>();
    final details = await c.loadPatientPrescriptionDetails(
      prescription.prescriptionId,
    );
    if (!mounted) return;

    if (details == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(c.error ?? 'Failed to load prescription details.'),
        ),
      );
      return;
    }

    try {
      final p = details.prescription;
      final pdfBytes = await buildNstuPrescriptionPdf(
        patientName: (p.name ?? '').trim().isEmpty ? 'Patient' : p.name!,
        mobile: (p.mobileNumber ?? '').trim().isEmpty ? '-' : p.mobileNumber!,
        age: p.age == null ? '-' : '${p.age} years',
        gender: (p.gender ?? '').trim().isEmpty ? '-' : p.gender!,
        bloodGroup: (c.patientProfile?.bloodGroup ?? '').trim().isEmpty
            ? '-'
            : c.patientProfile!.bloodGroup!,
        patientId: p.patientId?.toString() ?? '-',
        date: DateFormat(
          'd/M/yyyy',
        ).format((p.prescriptionDate ?? prescription.date).toLocal()),
        bp: (p.bp ?? '').trim().isEmpty ? '-' : p.bp!,
        temperature: (p.temperature ?? '').trim().isEmpty
            ? '-'
            : p.temperature!,
        diagnosis: (p.cc ?? '').trim().isEmpty ? '-' : p.cc!,
        suggestedTests: (p.test ?? '').trim().isEmpty ? '-' : p.test!,
        advice: (p.advice ?? '').trim().isEmpty ? '-' : p.advice!,
        nextVisit: (p.nextVisit ?? '').trim().isEmpty ? '-' : p.nextVisit!,
        medicines: details.items
            .map(
              (m) => PrescriptionMedicineLine(
                medicine: m.medicineName,
                dosage: (m.dosageTimes ?? '').trim().isEmpty
                    ? '-'
                    : m.dosageTimes!,
                frequency: (m.mealTiming ?? '').trim().isEmpty
                    ? '-'
                    : m.mealTiming!,
                duration: m.duration?.toString() ?? '-',
              ),
            )
            .toList(),
      );

      downloadFileBytes(
        pdfBytes,
        '${_safePrescriptionFileName(prescription)}.pdf',
        'application/pdf',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prescription PDF downloaded.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download prescription: $e')),
      );
    }
  }

  Widget _statusBadge(bool uploaded) {
    final color = uploaded ? const Color(0xFF059669) : const Color(0xFFD97706);
    final dot = uploaded ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: uploaded ? const Color(0xFFECFDF5) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: dot),
          const SizedBox(width: 6),
          Text(
            uploaded ? 'Final' : 'Pending',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionIcon({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    final enabled = onPressed != null;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
      color: enabled ? const Color(0xFF334155) : const Color(0xFF94A3B8),
      style: IconButton.styleFrom(
        minimumSize: const Size(42, 42),
        backgroundColor: enabled
            ? const Color(0xFFF1F5F9)
            : const Color(0xFFF8FAFC),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<RoleDashboardController>();
    final theme = Theme.of(context);
    final reports = _filtered(c.patientReports);
    final prescriptions = _filteredPrescriptions(c.patientPrescriptions);
    final total = reports.length;
    final start = total == 0 ? 0 : _page * _pageSize;
    final safeStart = start.clamp(0, total == 0 ? 0 : total - 1);
    final endExclusive = (safeStart + _pageSize).clamp(0, total);
    final pageRows = reports.sublist(safeStart, endExclusive);
    final canPrev = _page > 0;
    final canNext = endExclusive < total;

    return DashboardShell(
      child: c.isLoading && c.patientReports.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Container(
              color: _pageBg,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 14),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Prescriptions & Reports',
                                  style: theme.textTheme.headlineMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF0F172A),
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Track and download your doctor prescriptions and diagnostic reports',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: _textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: c.isLoading
                                ? null
                                : () => c.loadPatient(),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Refresh'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: () => _downloadAll(reports),
                            style: FilledButton.styleFrom(
                              backgroundColor: _primary,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.download_rounded),
                            label: const Text('Download All'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        total > 0
                            ? 'You have $total report${total > 1 ? 's' : ''} available for viewing.'
                            : 'No reports available yet.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: _textMuted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: TextField(
                                controller: _searchCtrl,
                                decoration: InputDecoration(
                                  hintText:
                                      'Search reports or prescriptions...',
                                  prefixIcon: const Icon(Icons.search),
                                  filled: true,
                                  fillColor: _surface,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: _border,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: _border,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: _primary,
                                      width: 1.2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (_searchCtrl.text.isNotEmpty)
                            IconButton(
                              tooltip: 'Clear search',
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _page = 0);
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'My Prescriptions',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (prescriptions.isNotEmpty)
                        Container(
                          decoration: BoxDecoration(
                            color: _surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _border),
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              horizontalMargin: 18,
                              columnSpacing: 30,
                              headingRowHeight: 50,
                              headingRowColor: WidgetStateProperty.all(
                                _headerBg,
                              ),
                              columns: const [
                                DataColumn(label: Text('PRESCRIPTION ID')),
                                DataColumn(label: Text('DOCTOR')),
                                DataColumn(label: Text('DATE')),
                                DataColumn(label: Text('ACTIONS')),
                              ],
                              rows: prescriptions
                                  .map(
                                    (p) => DataRow(
                                      cells: [
                                        DataCell(Text('#${p.prescriptionId}')),
                                        DataCell(Text(p.doctorName)),
                                        DataCell(
                                          Text(
                                            DateFormat(
                                              'dd MMM, yyyy',
                                            ).format(p.date.toLocal()),
                                          ),
                                        ),
                                        DataCell(
                                          Row(
                                            children: [
                                              _actionIcon(
                                                tooltip:
                                                    'View prescription details',
                                                onPressed: () =>
                                                    _viewPrescription(p),
                                                icon: Icons.visibility_outlined,
                                              ),
                                              const SizedBox(width: 6),
                                              _actionIcon(
                                                tooltip:
                                                    'Download prescription',
                                                onPressed: () =>
                                                    _downloadPrescription(p),
                                                icon: Icons.download_rounded,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'No doctor-submitted prescriptions found yet.',
                          ),
                        ),
                      const SizedBox(height: 16),
                      Text(
                        'Laboratory Reports',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (pageRows.isNotEmpty)
                        Container(
                          decoration: BoxDecoration(
                            color: _surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _border),
                            boxShadow: const [
                              BoxShadow(
                                color: Color.fromRGBO(15, 23, 42, 0.05),
                                blurRadius: 12,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              horizontalMargin: 18,
                              columnSpacing: 34,
                              headingRowHeight: 52,
                              dataRowMinHeight: 66,
                              dataRowMaxHeight: 72,
                              headingRowColor: WidgetStateProperty.all(
                                _headerBg,
                              ),
                              columns: const [
                                DataColumn(
                                  label: Text(
                                    'REPORT NAME',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'DATE',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'STATUS',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'ACTIONS',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                ),
                              ],
                              rows: pageRows
                                  .map(
                                    (r) => DataRow(
                                      cells: [
                                        DataCell(
                                          Row(
                                            children: [
                                              const CircleAvatar(
                                                radius: 16,
                                                backgroundColor: Color(
                                                  0xFFE8F1FF,
                                                ),
                                                child: Icon(
                                                  Icons.science_outlined,
                                                  size: 18,
                                                  color: Color(0xFF2563EB),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                r.testName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF1E293B),
                                                  fontSize: 17,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            DateFormat(
                                              'dd MMM, yyyy',
                                            ).format(r.date.toLocal()),
                                            style: const TextStyle(
                                              color: Color(0xFF334155),
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        DataCell(_statusBadge(r.isUploaded)),
                                        DataCell(
                                          Row(
                                            children: [
                                              _actionIcon(
                                                tooltip: 'View report',
                                                onPressed: r.isUploaded
                                                    ? () => _openReport(r)
                                                    : null,
                                                icon: Icons.visibility_outlined,
                                              ),
                                              const SizedBox(width: 6),
                                              _actionIcon(
                                                tooltip: 'Download report',
                                                onPressed: r.isUploaded
                                                    ? () => _downloadReport(r)
                                                    : null,
                                                icon: Icons.download_rounded,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 30),
                          child: Center(
                            child: Text('No reports found for current filter.'),
                          ),
                        ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            total == 0
                                ? 'Showing 0 reports'
                                : 'Showing ${safeStart + 1} to $endExclusive of $total reports',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: _textMuted,
                            ),
                          ),
                          const Spacer(),
                          OutlinedButton(
                            onPressed: canPrev
                                ? () => setState(() => _page = _page - 1)
                                : null,
                            child: const Text('Previous'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: canNext
                                ? () => setState(() => _page = _page + 1)
                                : null,
                            child: const Text('Next'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _headerBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _border),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Understanding Your Results',
                              style: TextStyle(
                                color: Color(0xFF0F172A),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              "Pending results usually take 24-48 hours. If you notice any anomalies or have questions about your 'Final' reports, please schedule a follow-up consultation with your primary physician.",
                              style: TextStyle(color: Color(0xFF475569)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
