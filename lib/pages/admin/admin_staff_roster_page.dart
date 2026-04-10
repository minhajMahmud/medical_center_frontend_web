import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import 'package:universal_html/html.dart' as html;

import '../../controllers/role_dashboard_controller.dart';
import '../../widgets/common/dashboard_shell.dart';

class AdminStaffRosterPage extends StatefulWidget {
  const AdminStaffRosterPage({super.key});

  @override
  State<AdminStaffRosterPage> createState() => _AdminStaffRosterPageState();
}

class _AdminStaffRosterPageState extends State<AdminStaffRosterPage> {
  DateTime _selectedDate = DateTime.now();
  final Map<String, String?> _pendingShiftByStaffId = <String, String?>{};
  bool _pendingInitialized = false;
  bool _savingAll = false;

  static const _shiftColumns = <_ShiftColumn>[
    _ShiftColumn(key: 'MORNING', label: 'Morning (08:00 - 14:00)'),
    _ShiftColumn(key: 'AFTERNOON', label: 'Evening (14:00 - 20:00)'),
    _ShiftColumn(key: 'NIGHT', label: 'Night (20:00 - 08:00)'),
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadData);
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    await context.read<RoleDashboardController>().loadAdminRostersForDate(
      _selectedDate,
    );
    if (!mounted) return;
    setState(() {
      _pendingInitialized = false;
    });
  }

  DateTime _dayOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _normalizeRole(String role) {
    final r = role.trim().toLowerCase();
    if (r.contains('doctor')) return 'doctor';
    if (r.contains('dispenser')) return 'nursing';
    if (r.contains('lab')) return 'nursing';
    return 'general';
  }

  Map<String, String?> _currentShiftByStaffId(RoleDashboardController c) {
    final current = <String, String?>{};
    final day = _dayOnly(_selectedDate);

    for (final row in c.adminRosters) {
      if (!_sameDay(_dayOnly(row.shiftDate), day)) continue;
      current[row.staffId.toString()] = row.shift.toUpperCase();
    }
    return current;
  }

  void _ensurePendingInitialized(RoleDashboardController c) {
    if (_pendingInitialized) return;
    final current = _currentShiftByStaffId(c);
    _pendingShiftByStaffId
      ..clear()
      ..addAll(current);
    _pendingInitialized = true;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked == null) return;
    setState(() {
      _selectedDate = picked;
      _pendingInitialized = false;
      _pendingShiftByStaffId.clear();
    });
    await _loadData();
  }

  Future<void> _resetPending(RoleDashboardController c) async {
    setState(() {
      _pendingInitialized = false;
      _pendingShiftByStaffId.clear();
    });
    _ensurePendingInitialized(c);
  }

  Future<void> _saveAll(RoleDashboardController c) async {
    if (_savingAll) return;
    setState(() => _savingAll = true);

    final messenger = ScaffoldMessenger.of(context);
    final current = _currentShiftByStaffId(c);
    final day = _dayOnly(_selectedDate);

    bool allOk = true;

    for (final staff in c.adminRosterStaff) {
      final staffId = staff.userId;
      final desired = _pendingShiftByStaffId[staffId]?.toUpperCase();
      final previous = current[staffId]?.toUpperCase();

      if (desired == previous) continue;

      final existingRows = c.adminRosters
          .where(
            (r) =>
                r.staffId.toString() == staffId &&
                _sameDay(_dayOnly(r.shiftDate), day),
          )
          .toList();

      for (final r in existingRows) {
        final rid = r.rosterId;
        if (rid == null) continue;
        final ok = await c.deleteAdminRosterAssignment(rid, day);
        if (!ok) {
          allOk = false;
          break;
        }
      }
      if (!allOk) break;

      if (desired != null) {
        final ok = await c.saveAdminRosterAssignment(
          staffId: staffId,
          shiftType: desired,
          shiftDate: day,
          timeRange: desired,
          status: 'ACTIVE',
        );
        if (!ok) {
          allOk = false;
          break;
        }
      }
    }

    if (mounted) {
      if (allOk) {
        await c.loadAdminRostersForDate(day);
        _pendingInitialized = false;
        _ensurePendingInitialized(c);
        messenger.showSnackBar(
          const SnackBar(content: Text('Roster saved successfully.')),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text(c.error ?? 'Failed to save roster changes.')),
        );
      }
      setState(() => _savingAll = false);
    }
  }

  int _coverageCount(String shiftKey) {
    return _pendingShiftByStaffId.values
        .where((s) => (s ?? '').toUpperCase() == shiftKey)
        .length;
  }

  String _shiftLabel(String? shiftKey) {
    switch ((shiftKey ?? '').toUpperCase()) {
      case 'MORNING':
        return 'Morning (08:00 - 14:00)';
      case 'AFTERNOON':
        return 'Evening (14:00 - 20:00)';
      case 'NIGHT':
        return 'Night (20:00 - 08:00)';
      default:
        return 'Unassigned';
    }
  }

  List<_RosterExportRow> _exportRowsForGroup(
    RoleDashboardController c,
    String group,
  ) {
    final staff =
        c.adminRosterStaff
            .where((s) => _normalizeRole(s.role) == group)
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

    return staff
        .map(
          (s) => _RosterExportRow(
            name: s.name,
            id: s.userId,
            role: s.role,
            shift: _shiftLabel(_pendingShiftByStaffId[s.userId]),
          ),
        )
        .toList();
  }

  Future<void> _exportPdf(RoleDashboardController c) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final doc = pw.Document();
      final dateText = DateFormat('dd MMM yyyy').format(_selectedDate);
      final fileDate = DateFormat('yyyyMMdd').format(_selectedDate);
      final logoBytes = (await rootBundle.load(
        'assets/images/nstu_logo.jpg',
      )).buffer.asUint8List();
      final logoImage = pw.MemoryImage(logoBytes);

      pw.Widget buildSection(String title, List<_RosterExportRow> rows) {
        return pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 18),
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            border: pw.Border.all(color: PdfColor.fromHex('#DDE5EE')),
            borderRadius: pw.BorderRadius.circular(10),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#0F172A'),
                ),
              ),
              pw.SizedBox(height: 10),
              if (rows.isEmpty)
                pw.Text(
                  'No staff available in this group.',
                  style: pw.TextStyle(color: PdfColor.fromHex('#64748B')),
                )
              else
                pw.TableHelper.fromTextArray(
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#334155'),
                    fontSize: 10,
                  ),
                  headerDecoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F8FAFC'),
                  ),
                  cellStyle: const pw.TextStyle(fontSize: 10),
                  cellPadding: const pw.EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 7,
                  ),
                  border: pw.TableBorder.all(
                    color: PdfColor.fromHex('#E2E8F0'),
                    width: 0.6,
                  ),
                  headers: const ['Staff Name', 'ID', 'Role', 'Assigned Shift'],
                  data: rows
                      .map((r) => [r.name, r.id, r.role, r.shift])
                      .toList(),
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
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 76,
                    height: 76,
                    padding: const pw.EdgeInsets.all(6),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(14),
                    ),
                    child: pw.Image(logoImage, fit: pw.BoxFit.contain),
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
                          'Staff Roster Schedule',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 16,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          'Date: $dateText',
                          style: pw.TextStyle(
                            color: PdfColor.fromHex('#D1FAE5'),
                            fontSize: 11,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'Noakhali Science and Technology University',
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
                _buildCoveragePdfCard(
                  'Morning Coverage',
                  _coverageCount('MORNING'),
                  15,
                ),
                pw.SizedBox(width: 10),
                _buildCoveragePdfCard(
                  'Evening Coverage',
                  _coverageCount('AFTERNOON'),
                  10,
                ),
                pw.SizedBox(width: 10),
                _buildCoveragePdfCard(
                  'Night Coverage',
                  _coverageCount('NIGHT'),
                  6,
                ),
              ],
            ),
            pw.SizedBox(height: 18),
            buildSection('Doctor Roster', _exportRowsForGroup(c, 'doctor')),
            buildSection(
              'Nursing Staff Roster',
              _exportRowsForGroup(c, 'nursing'),
            ),
            buildSection(
              'General Staff Roster',
              _exportRowsForGroup(c, 'general'),
            ),
          ],
        ),
      );

      final bytes = await doc.save();
      final blob = html.Blob(<dynamic>[bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', 'staff_roster_$fileDate.pdf')
        ..click();
      html.Url.revokeObjectUrl(url);

      messenger.showSnackBar(
        const SnackBar(content: Text('Roster PDF exported successfully.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to export roster PDF: $e')),
      );
    }
  }

  pw.Widget _buildCoveragePdfCard(String title, int count, int requiredCount) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex('#F8FAFC'),
          borderRadius: pw.BorderRadius.circular(10),
          border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColor.fromHex('#64748B'),
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              '$count Staff',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#0F172A'),
              ),
            ),
            pw.Text(
              '$requiredCount required',
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColor.fromHex('#64748B'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    RoleDashboardController c, {
    required String title,
    required String group,
  }) {
    final staff =
        c.adminRosterStaff
            .where((s) => _normalizeRole(s.role) == group)
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                  label: const Text('Add Staff Member'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: const [
                Expanded(
                  flex: 4,
                  child: Text(
                    'Staff Name',
                    style: TextStyle(
                      color: Color(0xFF334155),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(flex: 2, child: Center(child: Text('Morning'))),
                Expanded(flex: 2, child: Center(child: Text('Evening'))),
                Expanded(flex: 2, child: Center(child: Text('Night'))),
                SizedBox(width: 72, child: Center(child: Text('Actions'))),
              ],
            ),
          ),
          const Divider(height: 1),
          if (staff.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'No staff available in this group.',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            )
          else
            ...staff.map((s) {
              final selected = _pendingShiftByStaffId[s.userId]?.toUpperCase();
              final initials = s.name
                  .split(RegExp(r'\s+'))
                  .where((x) => x.isNotEmpty)
                  .take(2)
                  .map((x) => x[0].toUpperCase())
                  .join();

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: const Color(0xFFE8F1FF),
                                child: Text(
                                  initials.isEmpty ? 'S' : initials,
                                  style: const TextStyle(
                                    color: Color(0xFF1D4ED8),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${s.name} (ID: ${s.userId})',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      s.role,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        for (final shift in _shiftColumns)
                          Expanded(
                            flex: 2,
                            child: Center(
                              child: Checkbox(
                                value: selected == shift.key,
                                onChanged: (checked) {
                                  setState(() {
                                    if (checked == true) {
                                      _pendingShiftByStaffId[s.userId] =
                                          shift.key;
                                    } else {
                                      _pendingShiftByStaffId[s.userId] = null;
                                    }
                                  });
                                },
                                side: const BorderSide(
                                  color: Color(0xFF94A3B8),
                                ),
                                shape: const CircleBorder(),
                                activeColor: const Color(0xFF0D9488),
                              ),
                            ),
                          ),
                        SizedBox(
                          width: 72,
                          child: Center(
                            child: IconButton(
                              tooltip: 'Clear assignment',
                              onPressed: () {
                                setState(() {
                                  _pendingShiftByStaffId[s.userId] = null;
                                });
                              },
                              icon: const Icon(
                                Icons.remove_circle_outline_rounded,
                                color: Color(0xFF64748B),
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                ],
              );
            }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<RoleDashboardController>();
    _ensurePendingInitialized(c);

    final morningCount = _coverageCount('MORNING');
    final eveningCount = _coverageCount('AFTERNOON');
    final nightCount = _coverageCount('NIGHT');

    return DashboardShell(
      child: c.isLoading && c.adminRosterStaff.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Shift Scheduling',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Manage and assign shifts for all hospital departments.',
                            style: TextStyle(color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_month_outlined, size: 18),
                      label: Text(
                        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _exportPdf(c),
                      icon: const Icon(Icons.download_outlined, size: 18),
                      label: const Text('Export PDF'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _savingAll ? null : () => _saveAll(c),
                      icon: _savingAll
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined, size: 18),
                      label: const Text('Save All Rosters'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSection(
                  context,
                  c,
                  title: 'Doctor Roster',
                  group: 'doctor',
                ),
                const SizedBox(height: 14),
                _buildSection(
                  context,
                  c,
                  title: 'Nursing Staff Roster',
                  group: 'nursing',
                ),
                const SizedBox(height: 14),
                _buildSection(
                  context,
                  c,
                  title: 'General Staff Roster',
                  group: 'general',
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0B1736), Color(0xFF0F2A69)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _CoverageCard(
                            title: 'MORNING COVERAGE',
                            count: morningCount,
                            requiredCount: 15,
                          ),
                          const SizedBox(width: 16),
                          _CoverageCard(
                            title: 'EVENING COVERAGE',
                            count: eveningCount,
                            requiredCount: 10,
                          ),
                          const SizedBox(width: 16),
                          _CoverageCard(
                            title: 'NIGHT COVERAGE',
                            count: nightCount,
                            requiredCount: 6,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF334155)),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => _resetPending(c),
                            child: const Text('Reset All'),
                          ),
                          const SizedBox(width: 10),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0D9488),
                            ),
                            onPressed: _savingAll ? null : () => _saveAll(c),
                            child: const Text('Finalize Roster'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _ShiftColumn {
  const _ShiftColumn({required this.key, required this.label});

  final String key;
  final String label;
}

class _CoverageCard extends StatelessWidget {
  const _CoverageCard({
    required this.title,
    required this.count,
    required this.requiredCount,
  });

  final String title;
  final int count;
  final int requiredCount;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$count Staff',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(
                    text: ' / $requiredCount Required',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
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

class _RosterExportRow {
  const _RosterExportRow({
    required this.name,
    required this.id,
    required this.role,
    required this.shift,
  });

  final String name;
  final String id;
  final String role;
  final String shift;
}
