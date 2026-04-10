import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/role_dashboard_controller.dart';
import '../../widgets/common/app_data_table.dart';
import '../../widgets/common/dashboard_shell.dart';

class LabResultsPage extends StatefulWidget {
  const LabResultsPage({super.key});

  @override
  State<LabResultsPage> createState() => _LabResultsPageState();
}

class _LabResultsPageState extends State<LabResultsPage> {
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

    return DashboardShell(
      child: c.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Text(
                  'Lab • Test Results',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                AppDataTable(
                  columns: const [
                    DataColumn(label: Text('Result ID')),
                    DataColumn(label: Text('Patient')),
                    DataColumn(label: Text('Mobile')),
                    DataColumn(label: Text('Uploaded')),
                    DataColumn(label: Text('Submitted At')),
                  ],
                  rows: c.labResults
                      .map(
                        (r) => DataRow(
                          cells: [
                            DataCell(Text((r.resultId ?? 0).toString())),
                            DataCell(Text(r.patientName)),
                            DataCell(Text(r.mobileNumber)),
                            DataCell(Text(r.isUploaded ? 'Yes' : 'No')),
                            DataCell(
                              Text(
                                r.submittedAt == null
                                    ? '-'
                                    : DateFormat(
                                        'dd MMM yyyy',
                                      ).format(r.submittedAt!),
                              ),
                            ),
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
