import 'package:backend_client/backend_client.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/role_dashboard_controller.dart';
import '../../utils/csv_exporter.dart';
import '../../widgets/common/dashboard_shell.dart';

class LabAnalyticsPage extends StatefulWidget {
  const LabAnalyticsPage({super.key});

  @override
  State<LabAnalyticsPage> createState() => _LabAnalyticsPageState();
}

class _LabAnalyticsPageState extends State<LabAnalyticsPage> {
  _AnalyticsRange _selectedRange = _AnalyticsRange.last30;
  String _selectedPatientType = 'ALL';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      _refreshAnalytics();
    });
  }

  DateTime? _rangeStart(_AnalyticsRange range) {
    final now = DateTime.now();
    switch (range) {
      case _AnalyticsRange.last7:
        return DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 6));
      case _AnalyticsRange.last30:
        return DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 29));
      case _AnalyticsRange.last90:
        return DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 89));
      case _AnalyticsRange.all:
        return null;
    }
  }

  String _rangeLabel(_AnalyticsRange range) {
    switch (range) {
      case _AnalyticsRange.last7:
        return 'Last 7 Days';
      case _AnalyticsRange.last30:
        return 'Last 30 Days';
      case _AnalyticsRange.last90:
        return 'Last 90 Days';
      case _AnalyticsRange.all:
        return 'All Time';
    }
  }

  DateTime? _toDateExclusive(_AnalyticsRange range) {
    if (range == _AnalyticsRange.all) return null;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
  }

  Future<void> _refreshAnalytics() {
    return context.read<RoleDashboardController>().loadLabAnalyticsSnapshot(
      fromDate: _rangeStart(_selectedRange),
      toDateExclusive: _toDateExclusive(_selectedRange),
      patientType: _selectedPatientType,
    );
  }

  Future<void> _exportCsv(LabAnalyticsSnapshot snapshot) async {
    final b = StringBuffer();
    b.writeln('Metric,Value');
    b.writeln('Patient Type Filter,${snapshot.patientType}');
    b.writeln('From,${snapshot.fromDate?.toIso8601String() ?? 'ALL'}');
    b.writeln(
      'To (Exclusive),${snapshot.toDateExclusive?.toIso8601String() ?? 'ALL'}',
    );
    b.writeln('Total Results,${snapshot.totalResults}');
    b.writeln('Submitted Results,${snapshot.submittedResults}');
    b.writeln('Pending Results,${snapshot.pendingResults}');
    b.writeln('Urgent Results,${snapshot.urgentResults}');
    b.writeln('Average TAT Hours,${snapshot.avgTatHours.toStringAsFixed(2)}');
    b.writeln(
      'Estimated Revenue,${snapshot.estimatedRevenue.toStringAsFixed(2)}',
    );
    b.writeln(
      'Submitted Revenue,${snapshot.submittedRevenue.toStringAsFixed(2)}',
    );

    b.writeln();
    b.writeln('Daily Trend');
    b.writeln('Day,Total,Submitted');
    for (final p in snapshot.dailyTrend) {
      b.writeln(
        '${DateFormat('yyyy-MM-dd').format(p.day)},${p.total},${p.submitted}',
      );
    }

    b.writeln();
    b.writeln('Top Tests');
    b.writeln('Test Name,Count');
    for (final t in snapshot.topTests) {
      final safe = t.testName.replaceAll(',', ' ');
      b.writeln('$safe,${t.count}');
    }

    b.writeln();
    b.writeln('Category Distribution');
    b.writeln('Category,Count');
    for (final c in snapshot.categoryDistribution) {
      b.writeln('${c.category},${c.count}');
    }

    b.writeln();
    b.writeln('Shift Productivity');
    b.writeln('Shift,Total,Submitted,Productivity Percent');
    for (final s in snapshot.shiftProductivity) {
      b.writeln(
        '${s.shift},${s.total},${s.submitted},${s.productivityPercent.toStringAsFixed(2)}',
      );
    }

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    await exportCsvFile(
      fileName: 'lab_analytics_$timestamp.csv',
      csvContent: b.toString(),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Analytics CSV exported successfully.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<RoleDashboardController>();
    final snapshot = c.labAnalyticsSnapshot;

    final patientTypeOptions = const [
      'ALL',
      'STUDENT',
      'STAFF',
      'OUTSIDE',
      'URGENT',
    ];

    final criticalRate = (snapshot == null || snapshot.totalResults == 0)
        ? 0.0
        : (snapshot.urgentResults * 100.0) / snapshot.totalResults;

    return DashboardShell(
      child: c.isLabAnalyticsLoading && snapshot == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Lab Analytics Dashboard',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _RangePicker(
                      value: _selectedRange,
                      onChanged: (value) {
                        setState(() => _selectedRange = value);
                        _refreshAnalytics();
                      },
                    ),
                    const SizedBox(width: 10),
                    _PatientTypePicker(
                      value: _selectedPatientType,
                      options: patientTypeOptions,
                      onChanged: (value) {
                        setState(() => _selectedPatientType = value);
                        _refreshAnalytics();
                      },
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: snapshot == null
                          ? null
                          : () => _exportCsv(snapshot),
                      icon: const Icon(Icons.download),
                      label: const Text('Export CSV'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (c.error != null && c.error!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      c.error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _MetricCard(
                      title: 'Test Volume',
                      subtitle: _rangeLabel(_selectedRange),
                      value: '${snapshot?.totalResults ?? 0}',
                      icon: Icons.science_outlined,
                    ),
                    _MetricCard(
                      title: 'Submitted',
                      subtitle: 'Completed reports',
                      value: '${snapshot?.submittedResults ?? 0}',
                      icon: Icons.check_circle_outline,
                    ),
                    _MetricCard(
                      title: 'Pending',
                      subtitle: 'Awaiting submission',
                      value: '${snapshot?.pendingResults ?? 0}',
                      icon: Icons.pending_actions,
                    ),
                    _MetricCard(
                      title: 'Avg. TAT (Hours)',
                      subtitle: 'Submit - Created',
                      value: (snapshot?.avgTatHours ?? 0).toStringAsFixed(1),
                      icon: Icons.timer_outlined,
                    ),
                    _MetricCard(
                      title: 'Estimated Revenue',
                      subtitle: 'All tests in filter',
                      value:
                          '৳ ${(snapshot?.estimatedRevenue ?? 0).toStringAsFixed(0)}',
                      icon: Icons.currency_exchange,
                    ),
                    _MetricCard(
                      title: 'Submitted Revenue',
                      subtitle: 'Only submitted tests',
                      value:
                          '৳ ${(snapshot?.submittedRevenue ?? 0).toStringAsFixed(0)}',
                      icon: Icons.trending_up,
                    ),
                    _MetricCard(
                      title: 'Critical Flags Rate',
                      subtitle: 'Urgent cases share',
                      value: '${criticalRate.toStringAsFixed(1)}%',
                      icon: Icons.warning_amber_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _TrendCard(
                        trend: snapshot?.dailyTrend ?? const [],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _CategoryShareCard(
                        data: snapshot?.categoryDistribution ?? const [],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _TopTestsCard(
                        items: snapshot?.topTests ?? const [],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ShiftProductivityCard(
                        shiftStats: snapshot?.shiftProductivity ?? const [],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      'Data Source: SQL-aggregated backend snapshot from DB (`test_results` + `lab_tests`).',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

enum _AnalyticsRange { last7, last30, last90, all }

class _RangePicker extends StatelessWidget {
  const _RangePicker({required this.value, required this.onChanged});

  final _AnalyticsRange value;
  final ValueChanged<_AnalyticsRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<_AnalyticsRange>(
      value: value,
      items: const [
        DropdownMenuItem(
          value: _AnalyticsRange.last7,
          child: Text('Last 7 Days'),
        ),
        DropdownMenuItem(
          value: _AnalyticsRange.last30,
          child: Text('Last 30 Days'),
        ),
        DropdownMenuItem(
          value: _AnalyticsRange.last90,
          child: Text('Last 90 Days'),
        ),
        DropdownMenuItem(value: _AnalyticsRange.all, child: Text('All Time')),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

class _PatientTypePicker extends StatelessWidget {
  const _PatientTypePicker({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      value: options.contains(value) ? value : 'ALL',
      items: options
          .map((o) => DropdownMenuItem(value: o, child: Text(o)))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.trend});

  final List<LabAnalyticsDailyPoint> trend;

  @override
  Widget build(BuildContext context) {
    final hasData = trend.isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Test Volume Trend',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (!hasData)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('No trend data in selected range.'),
              )
            else
              SizedBox(
                height: 260,
                child: LineChart(
                  LineChartData(
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(show: true),
                    titlesData: FlTitlesData(
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: trend.length > 10 ? 2 : 1,
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();
                            if (i < 0 || i >= trend.length) {
                              return const SizedBox.shrink();
                            }
                            final day = trend[i].day;
                            return Text(
                              DateFormat('d MMM').format(day),
                              style: const TextStyle(fontSize: 10),
                            );
                          },
                        ),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: [
                          for (var i = 0; i < trend.length; i++)
                            FlSpot(i.toDouble(), trend[i].total.toDouble()),
                        ],
                        isCurved: true,
                        barWidth: 3,
                        color: const Color(0xFF1E88E5),
                        dotData: const FlDotData(show: false),
                      ),
                      LineChartBarData(
                        spots: [
                          for (var i = 0; i < trend.length; i++)
                            FlSpot(i.toDouble(), trend[i].submitted.toDouble()),
                        ],
                        isCurved: true,
                        barWidth: 3,
                        color: const Color(0xFF43A047),
                        dotData: const FlDotData(show: false),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children: const [
                _LegendDot(color: Color(0xFF1E88E5), label: 'Total Tests'),
                _LegendDot(color: Color(0xFF43A047), label: 'Submitted'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryShareCard extends StatelessWidget {
  const _CategoryShareCard({required this.data});

  final List<LabAnalyticsCategoryCount> data;

  @override
  Widget build(BuildContext context) {
    final entries = [...data]..sort((a, b) => b.count.compareTo(a.count));
    final total = entries.fold<int>(0, (p, e) => p + e.count);
    final palette = <Color>[
      const Color(0xFF1565C0),
      const Color(0xFF2E7D32),
      const Color(0xFF6A1B9A),
      const Color(0xFFEF6C00),
      const Color(0xFF455A64),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Patient Category Share',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Text('No category data in selected range.'),
              )
            else
              SizedBox(
                height: 220,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: [
                      for (var i = 0; i < entries.length; i++)
                        PieChartSectionData(
                          value: entries[i].count.toDouble(),
                          color: palette[i % palette.length],
                          title: total == 0
                              ? '0%'
                              : '${((entries[i].count * 100) / total).toStringAsFixed(0)}%',
                          radius: 60,
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            ...[
              for (var i = 0; i < entries.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: palette[i % palette.length],
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(entries[i].category)),
                      Text('${entries[i].count}'),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TopTestsCard extends StatelessWidget {
  const _TopTestsCard({required this.items});

  final List<LabAnalyticsTestCount> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top 5 Frequent Tests',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('No test frequency data in selected range.'),
              )
            else
              SizedBox(
                height: 240,
                child: BarChart(
                  BarChartData(
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(show: false),
                    titlesData: FlTitlesData(
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();
                            if (i < 0 || i >= items.length) {
                              return const SizedBox.shrink();
                            }
                            return Text(
                              items[i].testName,
                              style: const TextStyle(fontSize: 10),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: [
                      for (var i = 0; i < items.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: items[i].count.toDouble(),
                              width: 18,
                              borderRadius: BorderRadius.circular(6),
                              color: const Color(0xFF0D47A1),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ShiftProductivityCard extends StatelessWidget {
  const _ShiftProductivityCard({required this.shiftStats});

  final List<LabAnalyticsShiftStat> shiftStats;

  @override
  Widget build(BuildContext context) {
    final byName = {for (final s in shiftStats) s.shift: s};
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Shift Productivity',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            for (final key in const ['Morning', 'Afternoon', 'Night'])
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(key),
                        const Spacer(),
                        Text(
                          '${byName[key]?.submitted ?? 0}/${byName[key]?.total ?? 0} • ${(byName[key]?.productivityPercent ?? 0).toStringAsFixed(0)}%',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: ((byName[key]?.productivityPercent ?? 0) / 100)
                          .clamp(0.0, 1.0),
                      minHeight: 10,
                      borderRadius: BorderRadius.circular(8),
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
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFE8F1FF),
                child: Icon(icon),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
