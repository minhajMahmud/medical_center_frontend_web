import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/role_dashboard_controller.dart';
import '../../widgets/common/app_data_table.dart';
import '../../widgets/common/dashboard_shell.dart';

class PatientStaffInfoPage extends StatefulWidget {
  const PatientStaffInfoPage({super.key});

  @override
  State<PatientStaffInfoPage> createState() => _PatientStaffInfoPageState();
}

class _PatientStaffInfoPageState extends State<PatientStaffInfoPage> {
  String _safeEnumLabel(dynamic value) {
    if (value == null) return '-';

    try {
      final dynamic dyn = value;
      final String? name = dyn.name?.toString();
      if (name != null && name.trim().isNotEmpty) {
        return name;
      }
    } catch (_) {
      // Fallback to string parsing below.
    }

    final raw = value.toString();
    if (raw.isEmpty) return '-';
    final tail = raw.contains('.') ? raw.split('.').last : raw;
    return tail.trim().isEmpty ? '-' : tail;
  }

  String _phoneForStaffName(RoleDashboardController c, String staffName) {
    for (final d in c.patientDoctors) {
      if (d.name.trim().toLowerCase() == staffName.trim().toLowerCase()) {
        final phone = d.phone.trim();
        return phone.isEmpty ? '-' : phone;
      }
    }
    return '-';
  }

  Widget _statusChip({
    required String label,
    required Color background,
    required Color foreground,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<RoleDashboardController>().loadPatient();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final c = context.watch<RoleDashboardController>();
    final isCompact = MediaQuery.sizeOf(context).width < 900;
    final hasAnyData =
        c.patientDoctors.isNotEmpty ||
        c.patientOnDutyStaff.isNotEmpty ||
        c.patientAmbulanceContacts.isNotEmpty;
    final showingFallbackOnDuty =
        c.patientOnDutyStaff.isEmpty && c.patientDoctors.isNotEmpty;

    final onDutyRows = c.patientOnDutyStaff.isNotEmpty
        ? c.patientOnDutyStaff.asMap().entries.map((entry) {
            final index = entry.key;
            final s = entry.value;
            return DataRow(
              color: MaterialStatePropertyAll<Color?>(
                index.isOdd
                    ? colors.surfaceContainerHighest.withValues(alpha: 0.35)
                    : null,
              ),
              cells: [
                DataCell(Text(s.staffName)),
                DataCell(
                  _statusChip(
                    label: _safeEnumLabel(s.staffRole),
                    background: colors.primaryContainer,
                    foreground: colors.onPrimaryContainer,
                  ),
                ),
                DataCell(
                  _statusChip(
                    label:
                        '${_safeEnumLabel(s.shift)} · ${s.shiftDate.toString().split(' ').first}',
                    background: colors.tertiaryContainer,
                    foreground: colors.onTertiaryContainer,
                    icon: Icons.schedule,
                  ),
                ),
                DataCell(Text(_phoneForStaffName(c, s.staffName))),
              ],
            );
          }).toList()
        : c.patientDoctors.asMap().entries.map((entry) {
            final index = entry.key;
            final s = entry.value;
            return DataRow(
              color: MaterialStatePropertyAll<Color?>(
                index.isOdd
                    ? colors.surfaceContainerHighest.withValues(alpha: 0.35)
                    : null,
              ),
              cells: [
                DataCell(Text(s.name)),
                DataCell(
                  _statusChip(
                    label: (s.designation ?? '').trim().isEmpty
                        ? 'Medical Staff'
                        : s.designation!,
                    background: colors.primaryContainer,
                    foreground: colors.onPrimaryContainer,
                  ),
                ),
                DataCell(
                  _statusChip(
                    label: 'As available',
                    background: colors.tertiaryContainer,
                    foreground: colors.onTertiaryContainer,
                    icon: Icons.schedule,
                  ),
                ),
                DataCell(Text(s.phone.trim().isEmpty ? '-' : s.phone)),
              ],
            );
          }).toList();

    return DashboardShell(
      child: c.isLoading && !hasAnyData
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: colors.primary.withValues(alpha: 0.12),
                        child: Icon(
                          Icons.local_hospital,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Medical Support Directory',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Quick access to on-duty staff and emergency ambulance contacts.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: colors.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.groups_rounded, color: colors.primary),
                            const SizedBox(width: 8),
                            Text(
                              'On-duty Medical Staff',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (showingFallbackOnDuty)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: colors.secondaryContainer.withValues(
                                alpha: 0.45,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'No active roster found. Showing available medical staff from database.',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        if (onDutyRows.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(8),
                            child: Text('No on-duty staff data available.'),
                          )
                        else
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: AppDataTable(
                              columns: const [
                                DataColumn(label: Text('Name')),
                                DataColumn(label: Text('Role')),
                                DataColumn(label: Text('Shift')),
                                DataColumn(label: Text('Phone')),
                              ],
                              rows: onDutyRows,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: colors.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.local_taxi, color: colors.error),
                            const SizedBox(width: 8),
                            Text(
                              'University Ambulance Contacts',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (c.patientAmbulanceContacts.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(8),
                            child: Text(
                              'No ambulance contacts found in database.',
                            ),
                          )
                        else
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: AppDataTable(
                              columns: isCompact
                                  ? const [
                                      DataColumn(label: Text('Title')),
                                      DataColumn(label: Text('Hotline')),
                                      DataColumn(label: Text('Primary')),
                                    ]
                                  : const [
                                      DataColumn(label: Text('Title')),
                                      DataColumn(label: Text('Phone (EN)')),
                                      DataColumn(label: Text('Phone (BN)')),
                                      DataColumn(label: Text('Primary')),
                                    ],
                              rows: c.patientAmbulanceContacts
                                  .asMap()
                                  .entries
                                  .map((entry) {
                                    final index = entry.key;
                                    final a = entry.value;
                                    return DataRow(
                                      color: MaterialStatePropertyAll<Color?>(
                                        index.isOdd
                                            ? colors.surfaceContainerHighest
                                                  .withValues(alpha: 0.35)
                                            : null,
                                      ),
                                      cells: isCompact
                                          ? [
                                              DataCell(Text(a.contactTitle)),
                                              DataCell(
                                                Text(
                                                  '${a.phoneEn} / ${a.phoneBn}',
                                                ),
                                              ),
                                              DataCell(
                                                a.isPrimary
                                                    ? _statusChip(
                                                        label: 'Primary',
                                                        background: Colors
                                                            .orange
                                                            .withValues(
                                                              alpha: 0.18,
                                                            ),
                                                        foreground: Colors
                                                            .orange
                                                            .shade900,
                                                        icon: Icons.star,
                                                      )
                                                    : const SizedBox(),
                                              ),
                                            ]
                                          : [
                                              DataCell(Text(a.contactTitle)),
                                              DataCell(Text(a.phoneEn)),
                                              DataCell(Text(a.phoneBn)),
                                              DataCell(
                                                a.isPrimary
                                                    ? _statusChip(
                                                        label: 'Primary',
                                                        background: Colors
                                                            .orange
                                                            .withValues(
                                                              alpha: 0.18,
                                                            ),
                                                        foreground: Colors
                                                            .orange
                                                            .shade900,
                                                        icon: Icons.star,
                                                      )
                                                    : const SizedBox(),
                                              ),
                                            ],
                                    );
                                  })
                                  .toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
