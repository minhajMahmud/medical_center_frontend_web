import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../controllers/role_dashboard_controller.dart';
import '../../widgets/charts/admin_analytics_chart.dart';
import '../../widgets/common/app_data_table.dart';
import '../../widgets/common/dashboard_shell.dart';

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<RoleDashboardController>().loadAdmin();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<RoleDashboardController>();
    final a = c.adminAnalytics;
    final query = (GoRouterState.of(context).uri.queryParameters['q'] ?? '')
        .trim()
        .toLowerCase();

    final topMedicines = (a?.topMedicines ?? const [])
        .where(
          (m) => query.isEmpty
              ? true
              : '${m.medicineName} ${m.used}'.toLowerCase().contains(query),
        )
        .toList();

    return DashboardShell(
      child: c.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Text(
                  'Admin • Reports',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                if (a != null)
                  AdminAnalyticsChart(
                    monthly: a.monthlyBreakdown
                        .map((m) => ('M${m.month}', m.total))
                        .toList(),
                  ),
                const SizedBox(height: 12),
                Text(
                  'Top Medicines',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (query.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 10),
                    child: Text(
                      'Showing ${topMedicines.length} result(s) for "$query"',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                AppDataTable(
                  columns: const [
                    DataColumn(label: Text('Medicine')),
                    DataColumn(label: Text('Used')),
                  ],
                  rows: topMedicines
                      .map(
                        (m) => DataRow(
                          cells: [
                            DataCell(Text(m.medicineName)),
                            DataCell(Text(m.used.toString())),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
    );
  }
}
