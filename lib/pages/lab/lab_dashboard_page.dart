import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/role_dashboard_controller.dart';
import '../../widgets/common/dashboard_shell.dart';

class LabDashboardPage extends StatefulWidget {
  const LabDashboardPage({super.key});

  @override
  State<LabDashboardPage> createState() => _LabDashboardPageState();
}

class _LabDashboardPageState extends State<LabDashboardPage> {
  DateTime _from = DateTime.now().subtract(const Duration(days: 365));
  DateTime _to = DateTime.now();
  String _searchQuery = '';
  String _sortBy = 'All';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<RoleDashboardController>().loadLab();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<RoleDashboardController>();
    final summary = c.labSummary;
    final allResults = c.labResults;

    final dayStart = DateTime(_to.year, _to.month, _to.day);
    final dayEnd = DateTime(_to.year, _to.month, _to.day, 23, 59, 59, 999);

    final todaysResults = allResults.where((r) {
      final d = r.createdAt;
      if (d == null) return true; // Include pending tests with null createdAt
      return !d.isBefore(dayStart) && !d.isAfter(dayEnd);
    }).toList();

    final criticalToday = todaysResults.where((r) {
      final t = r.patientType.toUpperCase();
      return t == 'URGENT' || t == 'CRITICAL';
    }).length;

    final rangeStart = DateTime(_from.year, _from.month, _from.day);
    final rangeEnd = DateTime(_to.year, _to.month, _to.day, 23, 59, 59, 999);

    final rangeResults = allResults.where((r) {
      final d = r.createdAt;
      if (d == null) return true; // Include pending tests with null createdAt
      return !d.isBefore(rangeStart) && !d.isAfter(rangeEnd);
    }).toList();

    final oneYearStart = DateTime.now().subtract(const Duration(days: 365));
    final oneYearResults = allResults.where((r) {
      final d = r.createdAt;
      // Keep rows without createdAt visible so pending tests are not hidden.
      if (d == null) return true;
      return !d.isBefore(oneYearStart);
    }).toList();

    final yearPending = oneYearResults
        .where((r) => r.submittedAt == null)
        .length;
    final yearSubmitted = oneYearResults
        .where((r) => r.submittedAt != null)
        .length;

    final testNameById = <int, String>{
      for (final t in c.labAvailableTests)
        if (t.id != null)
          t.id!: t.testName.isEmpty ? 'Test ${t.id}' : t.testName,
    };

    final summaryByTest = <int, _TestSummary>{};
    for (final r in rangeResults) {
      final s = summaryByTest.putIfAbsent(r.testId, () => _TestSummary());
      s.total += 1;
      if (r.submittedAt == null) {
        s.pending += 1;
      } else {
        s.submitted += 1;
      }
    }

    final testRows =
        summaryByTest.entries.map((e) {
          final id = e.key;
          final s = e.value;
          return _TestSummaryRow(
            testId: id,
            testName: testNameById[id] ?? 'Test #$id',
            total: s.total,
            pending: s.pending,
            submitted: s.submitted,
          );
        }).toList()..sort((a, b) {
          final byPending = b.pending.compareTo(a.pending);
          if (byPending != 0) return byPending;
          final byTotal = b.total.compareTo(a.total);
          if (byTotal != 0) return byTotal;
          return a.testName.toLowerCase().compareTo(b.testName.toLowerCase());
        });

    var filteredRows = testRows.where((row) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return row.testName.toLowerCase().contains(q) ||
          row.testId.toString().contains(q);
    }).toList();

    if (_sortBy == 'Pending') {
      filteredRows.sort((a, b) => b.pending.compareTo(a.pending));
    } else if (_sortBy == 'Submitted') {
      filteredRows.sort((a, b) => b.submitted.compareTo(a.submitted));
    } else if (_sortBy == 'Total') {
      filteredRows.sort((a, b) => b.total.compareTo(a.total));
    }

    final pendingQueue = allResults.where((r) => r.submittedAt == null).toList()
      ..sort((a, b) {
        final ad = a.createdAt;
        final bd = b.createdAt;
        if (ad != null && bd != null) return bd.compareTo(ad);
        if (ad != null) return -1;
        if (bd != null) return 1;
        return (b.resultId ?? 0).compareTo(a.resultId ?? 0);
      });

    final topPendingQueue = pendingQueue.take(5).toList();

    final weeklyPoints = _buildWeeklyPoints(allResults);

    return DashboardShell(
      child: c.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Row(
                  children: [
                    Text(
                      'Dashboard',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.shield,
                      color: Color(0xFF16A34A),
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    const Text('System Health'),
                    const SizedBox(width: 16),
                    const Icon(
                      Icons.cloud_done,
                      color: Color(0xFF0EA5E9),
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Cloud Sync: ${DateFormat('d/M/yyyy').format(DateTime.now())}',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: 'lab1',
                              items: const [
                                DropdownMenuItem(
                                  value: 'lab1',
                                  child: Text('lab1'),
                                ),
                              ],
                              onChanged: null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            onChanged: (v) => setState(() => _searchQuery = v),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'Search Tests, Patients, etc...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _sortBy,
                              items: const [
                                DropdownMenuItem(
                                  value: 'All',
                                  child: Text('All'),
                                ),
                                DropdownMenuItem(
                                  value: 'Pending',
                                  child: Text('Pending'),
                                ),
                                DropdownMenuItem(
                                  value: 'Submitted',
                                  child: Text('Submitted'),
                                ),
                                DropdownMenuItem(
                                  value: 'Total',
                                  child: Text('Total'),
                                ),
                              ],
                              onChanged: (v) {
                                if (v != null) setState(() => _sortBy = v);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _Stat(
                      title: 'Pending Test\n(Last 12 Months)',
                      value: '$yearPending',
                      icon: Icons.analytics_outlined,
                      tint: const Color(0xFFFEE2E2),
                    ),
                    _Stat(
                      title: 'Submitted Tests\n(Last 12 Months)',
                      value: '$yearSubmitted',
                      icon: Icons.check_circle_outline,
                      tint: const Color(0xFFDBEAFE),
                    ),
                    _Stat(
                      title: 'Critical Results\n(Last 12 Months)',
                      value: '$criticalToday',
                      icon: Icons.warning_amber_outlined,
                      tint: const Color(0xFFF3F4F6),
                    ),
                    _Stat(
                      title: 'Today Pending',
                      value: '${summary?.todayPendingUploads ?? 0}',
                      icon: Icons.pending_actions,
                      tint: const Color(0xFFFCE7F3),
                    ),
                    _Stat(
                      title: 'Today Submitted',
                      value: '${summary?.todaySubmitted ?? 0}',
                      icon: Icons.task_alt,
                      tint: const Color(0xFFCCFBF1),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Patient Queue',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (topPendingQueue.isEmpty)
                          const Text('No pending patients right now.')
                        else
                          ...topPendingQueue.map(
                            (r) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(r.patientName),
                              subtitle: Text(
                                '${r.patientType} • ${r.mobileNumber}',
                              ),
                              trailing: Text(
                                r.createdAt == null
                                    ? '-'
                                    : DateFormat(
                                        'd/M/yyyy',
                                      ).format(r.createdAt!),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Test Summary',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _pickFrom(context),
                      icon: const Icon(Icons.calendar_month),
                      label: Text(
                        'From: ${DateFormat('dd/MM/yyyy').format(_from)}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _pickTo(context),
                      icon: const Icon(Icons.calendar_month),
                      label: Text(
                        'To: ${DateFormat('dd/MM/yyyy').format(_to)}',
                      ),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('PDF export can be added next.'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Generate PDF Report'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Card(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Test Name')),
                        DataColumn(label: Text('Total Requested')),
                        DataColumn(label: Text('Pending')),
                        DataColumn(label: Text('Submitted')),
                        DataColumn(label: Text('Action')),
                      ],
                      rows: filteredRows
                          .map(
                            (r) => DataRow(
                              cells: [
                                DataCell(Text(r.testName)),
                                DataCell(Text(r.total.toString())),
                                DataCell(Text(r.pending.toString())),
                                DataCell(Text(r.submitted.toString())),
                                DataCell(
                                  OutlinedButton(
                                    onPressed: () {},
                                    child: const Text('View Details'),
                                  ),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Weekly Test Volume (Pending vs. Submitted)',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const Spacer(),
                            const Text('Last 6 weeks'),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 220,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              for (final p in weeklyPoints)
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Expanded(
                                          child: LayoutBuilder(
                                            builder: (context, box) {
                                              final maxVal = weeklyPoints
                                                  .map(
                                                    (e) =>
                                                        e.pending > e.submitted
                                                        ? e.pending
                                                        : e.submitted,
                                                  )
                                                  .fold<int>(
                                                    1,
                                                    (a, b) => a > b ? a : b,
                                                  );
                                              final pendingH = maxVal == 0
                                                  ? 0.0
                                                  : (p.pending / maxVal) *
                                                        box.maxHeight;
                                              final submittedH = maxVal == 0
                                                  ? 0.0
                                                  : (p.submitted / maxVal) *
                                                        box.maxHeight;
                                              return Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Container(
                                                    width: 14,
                                                    height: pendingH,
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xFF3B82F6,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    width: 14,
                                                    height: submittedH,
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xFF64748B,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          p.label,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Row(
                          children: [
                            _LegendDot(
                              color: Color(0xFF3B82F6),
                              label: 'Pending',
                            ),
                            SizedBox(width: 16),
                            _LegendDot(
                              color: Color(0xFF64748B),
                              label: 'Submitted',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  List<_WeeklyPoint> _buildWeeklyPoints(List<dynamic> results) {
    final now = DateTime.now();
    final startOfCurrentWeek = now.subtract(Duration(days: now.weekday - 1));

    final points = <_WeeklyPoint>[];
    for (var i = 5; i >= 0; i--) {
      final from = DateTime(
        startOfCurrentWeek.year,
        startOfCurrentWeek.month,
        startOfCurrentWeek.day,
      ).subtract(Duration(days: i * 7));
      final to = from.add(const Duration(days: 7));

      var pending = 0;
      var submitted = 0;
      for (final r in results) {
        final d = r.createdAt;
        if (d == null) continue;
        if (!d.isBefore(from) && d.isBefore(to)) {
          if (r.submittedAt == null) {
            pending += 1;
          } else {
            submitted += 1;
          }
        }
      }

      points.add(
        _WeeklyPoint(
          label: '${6 - i + 1}w',
          pending: pending,
          submitted: submitted,
        ),
      );
    }

    return points;
  }

  Future<void> _pickFrom(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2020),
      lastDate: now,
    );

    if (picked == null) return;
    setState(() {
      _from = picked;
      if (_to.isBefore(_from)) {
        _to = _from;
      }
    });
  }

  Future<void> _pickTo(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _to,
      firstDate: DateTime(2020),
      lastDate: now,
    );

    if (picked == null) return;
    setState(() {
      _to = picked;
      if (_to.isBefore(_from)) {
        _from = _to;
      }
    });
  }
}

class _TestSummary {
  int total = 0;
  int pending = 0;
  int submitted = 0;
}

class _TestSummaryRow {
  const _TestSummaryRow({
    required this.testId,
    required this.testName,
    required this.total,
    required this.pending,
    required this.submitted,
  });

  final int testId;
  final String testName;
  final int total;
  final int pending;
  final int submitted;
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.title,
    required this.value,
    required this.icon,
    required this.tint,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(backgroundColor: tint, child: Icon(icon)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(title),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeeklyPoint {
  const _WeeklyPoint({
    required this.label,
    required this.pending,
    required this.submitted,
  });

  final String label;
  final int pending;
  final int submitted;
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}
