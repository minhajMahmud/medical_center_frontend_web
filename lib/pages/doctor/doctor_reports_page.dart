import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:universal_html/html.dart' as html;
import 'package:backend_client/backend_client.dart';

import '../../controllers/role_dashboard_controller.dart';
import '../../widgets/common/dashboard_shell.dart';

class DoctorReportsPage extends StatefulWidget {
  const DoctorReportsPage({super.key});

  @override
  State<DoctorReportsPage> createState() => _DoctorReportsPageState();
}

class _DoctorReportsPageState extends State<DoctorReportsPage> {
  static const _bg = Color(0xFFF8FAFC);
  static const _surface = Colors.white;
  static const _border = Color(0xFFE2E8F0);
  static const _primary = Color(0xFF2563EB);
  static const _textMuted = Color(0xFF64748B);

  final TextEditingController _searchCtrl = TextEditingController();
  final Map<String, String> _pdfObjectUrls = <String, String>{};
  String _filter = 'All';
  int? _selectedReportId;

  // Review panel state
  final TextEditingController _notesCtrl = TextEditingController();
  String? _reviewAction;
  bool _visibleToPatient = false;
  bool _submittingReview = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<RoleDashboardController>().loadDoctorReports();
    });

    _searchCtrl.addListener(() {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    for (final objectUrl in _pdfObjectUrls.values) {
      html.Url.revokeObjectUrl(objectUrl);
    }
    _searchCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
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

  void _onSelectReport(int? reportId, PatientExternalReport? report) {
    setState(() {
      _selectedReportId = reportId;
      _notesCtrl.text = report?.doctorNotes ?? '';
      _reviewAction = report?.reviewAction;
      _visibleToPatient = report?.visibleToPatient ?? false;
    });
  }

  String _statusOf(PatientExternalReport report) {
    return report.reviewed ? 'Final' : 'Pending';
  }

  bool _matchesFilter(PatientExternalReport report) {
    final status = _statusOf(report).toLowerCase();
    final type = report.type.toLowerCase();
    switch (_filter) {
      case 'Pending':
        return status == 'pending';
      case 'Final':
        return status == 'final';
      case 'Urgent':
        return type.contains('urgent');
      default:
        return true;
    }
  }

  List<PatientExternalReport> _filteredReports(
    List<PatientExternalReport> reports,
  ) {
    final q = _searchCtrl.text.trim().toLowerCase();
    final filtered = reports.where((r) {
      final baseMatch =
          q.isEmpty ||
          r.type.toLowerCase().contains(q) ||
          (r.reportId?.toString().contains(q) ?? false) ||
          r.patientId.toString().contains(q) ||
          (r.prescriptionId?.toString().contains(q) ?? false);
      return baseMatch && _matchesFilter(r);
    }).toList();

    filtered.sort((a, b) {
      final ad = a.createdAt ?? a.reportDate;
      final bd = b.createdAt ?? b.reportDate;
      return bd.compareTo(ad);
    });

    return filtered;
  }

  Future<void> _openReportFile(PatientExternalReport? report) async {
    if (report == null) return;
    final path = report.filePath.trim();
    if (path.isEmpty) return;
    var url = path;
    if (_isPdfUrl(path)) {
      final objectUrl = _pdfObjectUrls[path] ?? await _createPdfObjectUrl(path);
      if (objectUrl != null) {
        _pdfObjectUrls[path] = objectUrl;
        url = objectUrl;
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Direct PDF preview unavailable. Opening original file instead.',
            ),
          ),
        );
      }
    }
    html.window.open(url, '_blank');
  }

  void _downloadFile(String src) {
    final anchor = html.AnchorElement(href: src)
      ..download = 'lab_report.pdf'
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
  }

  Future<void> _markReviewed(PatientExternalReport report) async {
    if (report.reportId == null) return;
    final c = context.read<RoleDashboardController>();
    final ok = await c.markDoctorReportReviewed(report.reportId!);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Report marked reviewed.' : 'Failed to mark reviewed.',
        ),
      ),
    );

    if (ok) {
      await c.loadDoctorReports();
    }
  }

  Future<void> _submitReview(PatientExternalReport report) async {
    if (report.reportId == null) return;
    if (_reviewAction == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select an action.')));
      return;
    }
    setState(() => _submittingReview = true);
    final c = context.read<RoleDashboardController>();
    final ok = await c.submitDoctorReview(
      reportId: report.reportId!,
      notes: _notesCtrl.text.trim(),
      action: _reviewAction!,
      visibleToPatient: _visibleToPatient,
    );
    setState(() => _submittingReview = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Review submitted successfully.' : 'Failed to submit review.',
        ),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
    );
    if (ok) {
      await c.loadDoctorReports();
    }
  }

  Widget _statusBadge(PatientExternalReport report) {
    final isFinal = report.reviewed;
    final bg = isFinal ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7);
    final fg = isFinal ? const Color(0xFF166534) : const Color(0xFF92400E);
    final label = isFinal ? 'FINAL' : 'PENDING';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _embeddedPreview(PatientExternalReport report) {
    final src = report.filePath.trim();
    if (src.isEmpty) {
      return const Center(child: Text('No report file attached.'));
    }

    if (!kIsWeb) {
      return Center(
        child: TextButton.icon(
          onPressed: () => _openReportFile(report),
          icon: const Icon(Icons.open_in_new),
          label: const Text('Open report file'),
        ),
      );
    }

    if (_isPdfUrl(src)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.picture_as_pdf_outlined,
                size: 40,
                color: _textMuted,
              ),
              const SizedBox(height: 10),
              const Text(
                'Browser-safe PDF preview: open in a new tab.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () => _openReportFile(report),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Preview PDF'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _downloadFile(src),
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Download'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Image.network(
      src,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.broken_image_outlined,
                  size: 40,
                  color: _textMuted,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Inline preview unavailable for this file.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _openReportFile(report),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open file'),
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
    final reports = _filteredReports(c.doctorReports);
    final selected = reports.firstWhere(
      (r) => r.reportId == _selectedReportId,
      orElse: () => reports.isNotEmpty
          ? reports.first
          : PatientExternalReport(
              reportId: null,
              patientId: 0,
              type: '',
              reportDate: DateTime.now(),
              filePath: '',
              prescribedDoctorId: 0,
              uploadedBy: 0,
              reviewed: false,
            ),
    );
    final hasSelected = reports.isNotEmpty && selected.patientId != 0;

    return DashboardShell(
      child: c.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              color: _bg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lab Test Reports',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: Container(
                            decoration: BoxDecoration(
                              color: _surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _border),
                            ),
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    children: [
                                      TextField(
                                        controller: _searchCtrl,
                                        decoration: InputDecoration(
                                          hintText: 'Search reports...',
                                          prefixIcon: const Icon(Icons.search),
                                          filled: true,
                                          fillColor: const Color(0xFFF1F5F9),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        children:
                                            [
                                              'All',
                                              'Pending',
                                              'Final',
                                              'Urgent',
                                            ].map((f) {
                                              final selectedChip = _filter == f;
                                              return ChoiceChip(
                                                label: Text(f),
                                                selected: selectedChip,
                                                onSelected: (_) =>
                                                    setState(() => _filter = f),
                                              );
                                            }).toList(),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),
                                Expanded(
                                  child: reports.isEmpty
                                      ? const Center(
                                          child: Text('No reports found.'),
                                        )
                                      : ListView.builder(
                                          itemCount: reports.length,
                                          itemBuilder: (_, i) {
                                            final r = reports[i];
                                            final isSel =
                                                r.reportId ==
                                                    _selectedReportId ||
                                                (_selectedReportId == null &&
                                                    i == 0);
                                            return InkWell(
                                              onTap: () => _onSelectReport(
                                                r.reportId,
                                                r,
                                              ),
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: isSel
                                                      ? const Color(0xFFEFF6FF)
                                                      : Colors.transparent,
                                                  border: Border(
                                                    left: BorderSide(
                                                      color: isSel
                                                          ? _primary
                                                          : Colors.transparent,
                                                      width: 4,
                                                    ),
                                                  ),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 12,
                                                    ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            r.type.isEmpty
                                                                ? 'Lab Report'
                                                                : r.type,
                                                            style:
                                                                const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                ),
                                                          ),
                                                        ),
                                                        _statusBadge(r),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      'Patient: #${r.patientId}',
                                                      style: const TextStyle(
                                                        color: _textMuted,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      DateFormat(
                                                        'dd MMM, yyyy hh:mm a',
                                                      ).format(
                                                        (r.createdAt ??
                                                                r.reportDate)
                                                            .toLocal(),
                                                      ),
                                                      style: const TextStyle(
                                                        color: _textMuted,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 7,
                          child: Container(
                            decoration: BoxDecoration(
                              color: _surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _border),
                            ),
                            child: hasSelected
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Row(
                                          children: [
                                            OutlinedButton.icon(
                                              onPressed: () =>
                                                  _openReportFile(selected),
                                              icon: const Icon(Icons.zoom_in),
                                              label: const Text('Zoom'),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Report #${selected.reportId ?? '-'}',
                                              style: const TextStyle(
                                                color: _textMuted,
                                              ),
                                            ),
                                            const Spacer(),
                                            FilledButton.icon(
                                              onPressed: selected.reviewed
                                                  ? null
                                                  : () =>
                                                        _markReviewed(selected),
                                              icon: const Icon(Icons.verified),
                                              label: const Text(
                                                'Mark Reviewed',
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            OutlinedButton.icon(
                                              onPressed: () =>
                                                  _openReportFile(selected),
                                              icon: const Icon(Icons.download),
                                              label: const Text('Open File'),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Divider(height: 1),
                                      Expanded(
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Left: file preview + metadata
                                            Expanded(
                                              flex: 5,
                                              child: ListView(
                                                padding: const EdgeInsets.all(
                                                  16,
                                                ),
                                                children: [
                                                  Container(
                                                    height: 320,
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xFFF8FAFC,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                      border: Border.all(
                                                        color: _border,
                                                      ),
                                                    ),
                                                    clipBehavior:
                                                        Clip.antiAlias,
                                                    child: _embeddedPreview(
                                                      selected,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 14),
                                                  const Text(
                                                    'NSTU MEDICAL CENTER',
                                                    style: TextStyle(
                                                      color: _primary,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      fontSize: 20,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  const Text(
                                                    'Laboratory Report Details',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 10),
                                                  Wrap(
                                                    runSpacing: 6,
                                                    spacing: 14,
                                                    children: [
                                                      Text(
                                                        'Type: ${selected.type.isEmpty ? '-' : selected.type}',
                                                      ),
                                                      Text(
                                                        'Patient ID: ${selected.patientId}',
                                                      ),
                                                      Text(
                                                        'Prescription ID: ${selected.prescriptionId ?? '-'}',
                                                      ),
                                                      Text(
                                                        'Report Date: ${DateFormat('dd MMM yyyy').format(selected.reportDate.toLocal())}',
                                                      ),
                                                      Text(
                                                        'Received: ${DateFormat('dd MMM yyyy hh:mm a').format((selected.createdAt ?? selected.reportDate).toLocal())}',
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const VerticalDivider(width: 1),
                                            // Right: Doctor Review panel
                                            SizedBox(
                                              width: 270,
                                              child: ListView(
                                                padding: const EdgeInsets.all(
                                                  16,
                                                ),
                                                children: [
                                                  Row(
                                                    children: [
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              6,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: const Color(
                                                            0xFFEFF6FF,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                        ),
                                                        child: const Icon(
                                                          Icons.rate_review,
                                                          color: _primary,
                                                          size: 18,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      const Text(
                                                        'Doctor Review',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          fontSize: 15,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 16),
                                                  const Text(
                                                    'Clinical Observations',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  TextField(
                                                    controller: _notesCtrl,
                                                    maxLines: 5,
                                                    enabled: !selected.reviewed,
                                                    decoration: InputDecoration(
                                                      hintText:
                                                          'Enter patient-specific clinical notes here...',
                                                      hintStyle:
                                                          const TextStyle(
                                                            color: _textMuted,
                                                            fontSize: 12,
                                                          ),
                                                      filled: true,
                                                      fillColor:
                                                          selected.reviewed
                                                          ? const Color(
                                                              0xFFF1F5F9,
                                                            )
                                                          : Colors.white,
                                                      border: OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                        borderSide:
                                                            const BorderSide(
                                                              color: _border,
                                                            ),
                                                      ),
                                                      enabledBorder:
                                                          OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8,
                                                                ),
                                                            borderSide:
                                                                const BorderSide(
                                                                  color:
                                                                      _border,
                                                                ),
                                                          ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 14),
                                                  const Text(
                                                    'Action Required',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  DropdownButtonHideUnderline(
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: selected.reviewed
                                                            ? const Color(
                                                                0xFFF1F5F9,
                                                              )
                                                            : Colors.white,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                        border: Border.all(
                                                          color: _border,
                                                        ),
                                                      ),
                                                      child: DropdownButton<String>(
                                                        value: _reviewAction,
                                                        isExpanded: true,
                                                        hint: const Text(
                                                          'Select an action...',
                                                        ),
                                                        items: const [
                                                          DropdownMenuItem(
                                                            value: 'Normal',
                                                            child: Text(
                                                              'Normal',
                                                            ),
                                                          ),
                                                          DropdownMenuItem(
                                                            value:
                                                                'Follow Up Required',
                                                            child: Text(
                                                              'Follow Up Required',
                                                            ),
                                                          ),
                                                          DropdownMenuItem(
                                                            value: 'Urgent',
                                                            child: Text(
                                                              'Urgent',
                                                            ),
                                                          ),
                                                          DropdownMenuItem(
                                                            value:
                                                                'Refer to Specialist',
                                                            child: Text(
                                                              'Refer to Specialist',
                                                            ),
                                                          ),
                                                          DropdownMenuItem(
                                                            value: 'No Action',
                                                            child: Text(
                                                              'No Action',
                                                            ),
                                                          ),
                                                        ],
                                                        onChanged:
                                                            selected.reviewed
                                                            ? null
                                                            : (v) => setState(
                                                                () =>
                                                                    _reviewAction =
                                                                        v,
                                                              ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 12),
                                                  CheckboxListTile(
                                                    value: _visibleToPatient,
                                                    onChanged: selected.reviewed
                                                        ? null
                                                        : (v) => setState(
                                                            () =>
                                                                _visibleToPatient =
                                                                    v ?? false,
                                                          ),
                                                    title: const Text(
                                                      'Make comments visible on Patient Portal',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                    contentPadding:
                                                        EdgeInsets.zero,
                                                    controlAffinity:
                                                        ListTileControlAffinity
                                                            .leading,
                                                  ),
                                                  const SizedBox(height: 8),
                                                  if (selected.reviewed &&
                                                      (selected
                                                              .doctorNotes
                                                              ?.isNotEmpty ??
                                                          false)) ...[
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            10,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                          0xFFF0FDF4,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                        border: Border.all(
                                                          color: const Color(
                                                            0xFFBBF7D0,
                                                          ),
                                                        ),
                                                      ),
                                                      child: Text(
                                                        selected.doctorNotes!,
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                          color: Color(
                                                            0xFF166534,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                  ],
                                                  SizedBox(
                                                    width: double.infinity,
                                                    child: FilledButton.icon(
                                                      onPressed:
                                                          (selected.reviewed ||
                                                              _submittingReview)
                                                          ? null
                                                          : () => _submitReview(
                                                              selected,
                                                            ),
                                                      icon: _submittingReview
                                                          ? const SizedBox(
                                                              width: 16,
                                                              height: 16,
                                                              child:
                                                                  CircularProgressIndicator(
                                                                    strokeWidth:
                                                                        2,
                                                                    color: Colors
                                                                        .white,
                                                                  ),
                                                            )
                                                          : const Icon(
                                                              Icons
                                                                  .verified_user,
                                                            ),
                                                      label: Text(
                                                        selected.reviewed
                                                            ? 'Approved & Signed Off'
                                                            : 'Approve & Sign Off',
                                                      ),
                                                      style: FilledButton.styleFrom(
                                                        backgroundColor:
                                                            selected.reviewed
                                                            ? Colors
                                                                  .green
                                                                  .shade700
                                                            : _primary,
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              vertical: 14,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                  if (selected.reviewedAt !=
                                                      null) ...[
                                                    const SizedBox(height: 10),
                                                    Text(
                                                      'DIGITALLY SIGNED | ${DateFormat('dd MMM yyyy hh:mm a').format(selected.reviewedAt!.toLocal()).toUpperCase()}',
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                        color: _textMuted,
                                                        letterSpacing: 0.3,
                                                      ),
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  )
                                : const Center(
                                    child: Text(
                                      'Select a report from the list.',
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
