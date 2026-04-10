import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/role_dashboard_controller.dart';
import '../../widgets/common/dashboard_shell.dart';

class PatientDashboardPage extends StatefulWidget {
  const PatientDashboardPage({super.key});

  @override
  State<PatientDashboardPage> createState() => _PatientDashboardPageState();
}

class _PatientDashboardPageState extends State<PatientDashboardPage> {
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
    final controller = context.watch<RoleDashboardController>();
    final profile = controller.patientProfile;

    final reports = [...controller.patientReports]
      ..sort((a, b) => b.date.compareTo(a.date));
    final recentReports = reports.take(3).toList();

    final appointments = [...controller.patientAppointments]
      ..sort((a, b) => a.date.compareTo(b.date));
    final nextAppointment = appointments.isNotEmpty ? appointments.first : null;

    final displayName = (profile?.name.trim().isNotEmpty ?? false)
        ? profile!.name.trim().split(' ').first
        : 'Patient';
    final patientIdSuffix = (profile?.phone ?? '').replaceAll(
      RegExp(r'\D'),
      '',
    );
    final patientBadgeId = patientIdSuffix.length >= 6
        ? 'NSTU-MED-${patientIdSuffix.substring(patientIdSuffix.length - 6)}'
        : 'NSTU-MED-000000';

    return DashboardShell(
      child: controller.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back, $displayName',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                ),
                          ),
                          const SizedBox(height: 4),
                          RichText(
                            text: TextSpan(
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: const Color(0xFF334155)),
                              children: [
                                const TextSpan(text: 'Patient ID: '),
                                TextSpan(
                                  text: patientBadgeId,
                                  style: const TextStyle(
                                    color: Color(0xFF2563EB),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const TextSpan(
                                  text: '  •  Have a healthy day!',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/patient/reports'),
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Prescriptions & Reports'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _QuickActionCard(
                        title: 'Book Appointment',
                        subtitle:
                            'Schedule a visit with your preferred specialist.',
                        icon: Icons.event_available_rounded,
                        highlighted: true,
                        onTap: () => context.go('/patient/appointments'),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _QuickActionCard(
                        title: 'View Prescriptions & Reports',
                        subtitle:
                            'Access and download your prescriptions and reports.',
                        icon: Icons.description_outlined,
                        onTap: () => context.go('/patient/reports'),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _QuickActionCard(
                        title: 'Check Availability',
                        subtitle: 'Real-time ambulance and staff tracking.',
                        icon: Icons.medical_services_outlined,
                        onTap: () => context.go('/patient/staff'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          _RecentReportsCard(reports: recentReports),
                          const SizedBox(height: 14),
                          const _InfoBannerCard(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        children: [
                          _NextAppointmentCard(appointment: nextAppointment),
                          const SizedBox(height: 14),
                          _PatientSnapshotCard(profile: profile),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.highlighted = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final bg = highlighted ? const Color(0xFF1D75DB) : Colors.white;
    final fg = highlighted ? Colors.white : const Color(0xFF0F172A);
    final sub = highlighted ? const Color(0xFFDBEAFF) : const Color(0xFF475569);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: highlighted
                ? const Color(0xFF1D75DB)
                : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: highlighted
                  ? const Color.fromRGBO(37, 99, 235, 0.25)
                  : const Color.fromRGBO(15, 23, 42, 0.05),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: highlighted
                    ? const Color.fromRGBO(255, 255, 255, 0.15)
                    : const Color(0xFFE8F1FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: highlighted ? Colors.white : const Color(0xFF2563EB),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                color: fg,
                fontSize: 30 / 2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(subtitle, style: TextStyle(color: sub, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class _RecentReportsCard extends StatelessWidget {
  const _RecentReportsCard({required this.reports});

  final List<dynamic> reports;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Text(
                  'Recent Lab Reports',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => context.go('/patient/reports'),
                  child: const Text('View Prescriptions & Reports'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (reports.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('No reports available yet.'),
            )
          else
            DataTable(
              horizontalMargin: 16,
              headingRowHeight: 40,
              dataRowMinHeight: 54,
              dataRowMaxHeight: 58,
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              columns: const [
                DataColumn(label: Text('REPORT NAME')),
                DataColumn(label: Text('DATE')),
                DataColumn(label: Text('STATUS')),
                DataColumn(label: Text('ACTION')),
              ],
              rows: reports.map((r) {
                final report = r as dynamic;
                return DataRow(
                  cells: [
                    DataCell(Text(report.testName.toString())),
                    DataCell(
                      Text(
                        DateFormat(
                          'dd MMM, yyyy',
                        ).format(report.date.toLocal()),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: report.isUploaded
                              ? const Color(0xFFDCFCE7)
                              : const Color(0xFFFFEDD5),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          report.isUploaded ? 'Final' : 'Pending',
                          style: TextStyle(
                            color: report.isUploaded
                                ? const Color(0xFF15803D)
                                : const Color(0xFFC2410C),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        report.isUploaded ? 'View' : 'Processing',
                        style: TextStyle(
                          color: report.isUploaded
                              ? const Color(0xFF2563EB)
                              : const Color(0xFF94A3B8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _NextAppointmentCard extends StatelessWidget {
  const _NextAppointmentCard({required this.appointment});

  final dynamic appointment;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Next Appointment',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          if (appointment == null)
            const Text('No upcoming appointment found.')
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appointment.doctorName as String,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    DateFormat(
                      'EEEE, dd MMM yyyy',
                    ).format(appointment.date as DateTime),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('hh:mm a').format(appointment.date as DateTime),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => context.go('/patient/appointments'),
              child: const Text('Reschedule'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.go('/patient/appointments'),
              child: const Text('Open Appointments'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBannerCard extends StatelessWidget {
  const _InfoBannerCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Wellness Tip of the Day',
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w700,
              fontSize: 22 / 1.8,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Drinking at least 8 glasses of water daily helps maintain kidney function and keeps your skin glowing. Try carrying a reusable bottle to track your progress!',
            style: TextStyle(color: Color(0xFF334155)),
          ),
        ],
      ),
    );
  }
}

class _PatientSnapshotCard extends StatelessWidget {
  const _PatientSnapshotCard({required this.profile});

  final dynamic profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Patient Snapshot',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          _SnapshotRow(
            label: 'Blood Group',
            value: (profile?.bloodGroup?.toString().isNotEmpty ?? false)
                ? profile.bloodGroup.toString()
                : 'Not set',
          ),
          _SnapshotRow(
            label: 'Gender',
            value: (profile?.gender?.toString().isNotEmpty ?? false)
                ? profile.gender.toString()
                : 'Not set',
          ),
          _SnapshotRow(
            label: 'Phone',
            value: (profile?.phone?.toString().isNotEmpty ?? false)
                ? profile.phone.toString()
                : '-',
          ),
          _SnapshotRow(label: 'Reports', value: 'Available in My Reports'),
        ],
      ),
    );
  }
}

class _SnapshotRow extends StatelessWidget {
  const _SnapshotRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF475569)),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
