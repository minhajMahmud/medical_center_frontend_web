import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/role_dashboard_controller.dart';
import '../../widgets/common/dashboard_shell.dart';

class _DoctorUiColors {
  static const Color ink = Color(0xFF0F172A);
  static const Color muted = Color(0xFF64748B);
  static const Color panel = Color(0xFFFFFFFF);
  static const Color panelAlt = Color(0xFFF8FBFF);
  static const Color border = Color(0xFFDCE7F5);
  static const Color primary = Color(0xFF1D4ED8);
  static const Color primarySoft = Color(0xFFE7F0FF);
  static const Color emerald = Color(0xFF059669);
  static const Color danger = Color(0xFFDC2626);
}

class DoctorDashboardPage extends StatefulWidget {
  const DoctorDashboardPage({super.key});

  @override
  State<DoctorDashboardPage> createState() => _DoctorDashboardPageState();
}

class _DoctorDashboardPageState extends State<DoctorDashboardPage> {
  String? _profilePictureUrl;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<RoleDashboardController>().loadDoctor();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _bindProfile(dynamic p) {
    _profilePictureUrl = p?.profilePictureUrl;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<RoleDashboardController>();
    final profile = c.doctorProfile;
    final home = c.doctorHome;
    _bindProfile(profile);

    final activities = _buildActivities(home);
    final reviewedReports = home?.reviewedReports ?? const [];

    return DashboardShell(
      child: c.isLoading && home == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _DoctorWelcomeHeader(
                  home: home,
                  profilePictureUrl: _profilePictureUrl,
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _OverviewCard(
                      title: 'Today',
                      icon: Icons.calendar_month_rounded,
                      value: home == null
                          ? '-'
                          : DateFormat('d/M/yyyy').format(home.today.toLocal()),
                      deltaText: _deltaText(
                        current: home?.todayPrescriptions ?? 0,
                        previous: home?.yesterdayPrescriptions ?? 0,
                        positiveLabel: 'vs. yesterday',
                        negativeLabel: 'vs. yesterday',
                      ),
                      deltaPositive:
                          (home?.todayPrescriptions ?? 0) >=
                          (home?.yesterdayPrescriptions ?? 0),
                    ),
                    _OverviewCard(
                      title: 'Last Month Prescriptions',
                      icon: Icons.medical_information_rounded,
                      value: '${home?.lastMonthPrescriptions ?? 0}',
                      deltaText: _deltaText(
                        current: home?.lastMonthPrescriptions ?? 0,
                        previous: home?.previousMonthPrescriptions ?? 0,
                        positiveLabel: 'vs. prev month',
                        negativeLabel: 'vs. prev month',
                      ),
                      deltaPositive:
                          (home?.lastMonthPrescriptions ?? 0) >=
                          (home?.previousMonthPrescriptions ?? 0),
                    ),
                    _OverviewCard(
                      title: 'Last Week Prescriptions',
                      icon: Icons.vaccines_rounded,
                      value: '${home?.lastWeekPrescriptions ?? 0}',
                      deltaText: _deltaText(
                        current: home?.lastWeekPrescriptions ?? 0,
                        previous: home?.previousWeekPrescriptions ?? 0,
                        positiveLabel: 'vs. last week',
                        negativeLabel: 'vs. last week',
                      ),
                      deltaPositive:
                          (home?.lastWeekPrescriptions ?? 0) >=
                          (home?.previousWeekPrescriptions ?? 0),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _ReportsPanel(
                        reports: reviewedReports,
                        onRefresh: () => c.loadDoctor(),
                        onArchive: () => context.go('/doctor/records'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        children: [
                          _RecentActivityPanel(activities: activities),
                          const SizedBox(height: 16),
                          _NextFollowUpCard(
                            home: home,
                            profilePictureUrl: _profilePictureUrl,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  String _deltaText({
    required int current,
    required int previous,
    required String positiveLabel,
    required String negativeLabel,
  }) {
    if (previous == 0) {
      if (current == 0) return '0% $positiveLabel';
      return '+100% $positiveLabel';
    }
    final percent = ((current - previous) / previous) * 100;
    final sign = percent >= 0 ? '+' : '';
    final label = percent >= 0 ? positiveLabel : negativeLabel;
    return '$sign${percent.toStringAsFixed(0)}% $label';
  }

  List<_ActivityItemData> _buildActivities(dynamic home) {
    final items = <_ActivityItemData>[];
    for (final item in home?.recent ?? const []) {
      items.add(
        _ActivityItemData(
          title: item.title,
          subtitle: item.subtitle,
          timeAgo: item.timeAgo,
          icon: Icons.medical_services_rounded,
          color: const Color(0xFFE8F1FF),
          iconColor: const Color(0xFF2563EB),
        ),
      );
    }
    for (final report in home?.reviewedReports ?? const []) {
      items.add(
        _ActivityItemData(
          title: report.type.isEmpty ? 'New Lab Result' : report.type,
          subtitle: report.uploadedByName.isEmpty
              ? 'Diagnostic report received'
              : 'Patient: ${report.uploadedByName}',
          timeAgo: report.timeAgo,
          icon: Icons.science_rounded,
          color: const Color(0xFFF3E8FF),
          iconColor: const Color(0xFF7C3AED),
        ),
      );
    }
    if (items.isEmpty) {
      items.add(
        const _ActivityItemData(
          title: 'No recent activity',
          subtitle: 'New prescriptions and reports will appear here.',
          timeAgo: '',
          icon: Icons.history_toggle_off_rounded,
          color: Color(0xFFF1F5F9),
          iconColor: Color(0xFF64748B),
        ),
      );
    }
    return items.take(4).toList();
  }
}

class _DoctorWelcomeHeader extends StatelessWidget {
  const _DoctorWelcomeHeader({
    required this.home,
    required this.profilePictureUrl,
  });

  final dynamic home;
  final String? profilePictureUrl;

  @override
  Widget build(BuildContext context) {
    final name = (home?.doctorName as String?)?.trim();
    final designation = (home?.doctorDesignation as String?)?.trim();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFF3F8FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _DoctorUiColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F1E3A8A),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, ${name?.isNotEmpty == true ? 'Dr. $name' : 'Doctor'}',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: _DoctorUiColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  designation?.isNotEmpty == true
                      ? 'Here is what\'s happening at NSTU Medical Center today • $designation'
                      : 'Here is what\'s happening at NSTU Medical Center today.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: _DoctorUiColors.muted),
                ),
              ],
            ),
          ),
          CircleAvatar(
            radius: 30,
            backgroundColor: _DoctorUiColors.primarySoft,
            backgroundImage:
                profilePictureUrl != null && profilePictureUrl!.isNotEmpty
                ? NetworkImage(profilePictureUrl!)
                : (home?.doctorProfilePictureUrl != null &&
                      (home.doctorProfilePictureUrl as String).isNotEmpty)
                ? NetworkImage(home.doctorProfilePictureUrl as String)
                : null,
            child:
                ((profilePictureUrl == null || profilePictureUrl!.isEmpty) &&
                    (home?.doctorProfilePictureUrl == null ||
                        (home.doctorProfilePictureUrl as String).isEmpty))
                ? const Icon(Icons.person, size: 30, color: Color(0xFF1D4ED8))
                : null,
          ),
        ],
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.title,
    required this.icon,
    required this.value,
    required this.deltaText,
    required this.deltaPositive,
  });

  final String title;
  final IconData icon;
  final String value;
  final String deltaText;
  final bool deltaPositive;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Container(
        decoration: BoxDecoration(
          color: _DoctorUiColors.panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _DoctorUiColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x101E3A8A),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: _DoctorUiColors.muted,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _DoctorUiColors.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: _DoctorUiColors.primary, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: _DoctorUiColors.ink,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    deltaPositive ? Icons.trending_up : Icons.trending_down,
                    size: 16,
                    color: deltaPositive
                        ? _DoctorUiColors.emerald
                        : _DoctorUiColors.danger,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      deltaText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: deltaPositive
                            ? _DoctorUiColors.emerald
                            : _DoctorUiColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
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

class _ReportsPanel extends StatelessWidget {
  const _ReportsPanel({
    required this.reports,
    required this.onRefresh,
    required this.onArchive,
  });

  final List<dynamic> reports;
  final VoidCallback onRefresh;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final hasReports = reports.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: _DoctorUiColors.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _DoctorUiColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reports',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Summary for the last 24 hours',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _DoctorUiColors.muted,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                TextButton(onPressed: onArchive, child: const Text('View all')),
              ],
            ),
            const SizedBox(height: 16),
            if (!hasReports)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 48,
                  horizontal: 24,
                ),
                decoration: BoxDecoration(
                  color: _DoctorUiColors.panelAlt,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _DoctorUiColors.border),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFFE2E8F0),
                      child: Icon(
                        Icons.monitor_heart_outlined,
                        color: Colors.blueGrey.shade400,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'No reports found',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'There are no diagnostic reports to review from the last 24 hours.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 10,
                      children: [
                        FilledButton(
                          onPressed: onRefresh,
                          child: const Text('Refresh'),
                        ),
                        OutlinedButton(
                          onPressed: onArchive,
                          child: const Text('Check Archive'),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              ...reports
                  .take(5)
                  .map(
                    (report) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE7F0FF),
                        child: Icon(
                          Icons.science_rounded,
                          color: Color(0xFF1D4ED8),
                        ),
                      ),
                      title: Text(
                        report.type.isEmpty ? 'Lab Result' : report.type,
                      ),
                      subtitle: Text(
                        report.uploadedByName.isEmpty
                            ? report.timeAgo
                            : 'Patient: ${report.uploadedByName} • ${report.timeAgo}',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _RecentActivityPanel extends StatelessWidget {
  const _RecentActivityPanel({required this.activities});

  final List<_ActivityItemData> activities;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _DoctorUiColors.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _DoctorUiColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Activity',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            ...activities.map(
              (activity) => Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: activity.color,
                      child: Icon(
                        activity.icon,
                        color: activity.iconColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activity.title,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            activity.subtitle,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: _DoctorUiColors.muted),
                          ),
                          if (activity.timeAgo.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              activity.timeAgo,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: const Color(0xFF8AA0BE)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {},
                child: const Text('Load more activity'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextFollowUpCard extends StatelessWidget {
  const _NextFollowUpCard({
    required this.home,
    required this.profilePictureUrl,
  });

  final dynamic home;
  final String? profilePictureUrl;

  @override
  Widget build(BuildContext context) {
    final patientName = (home?.nextFollowUpPatientName as String?)?.trim();
    final note = (home?.nextFollowUpNote as String?)?.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E40AF), Color(0xFF0EA5A4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A1E3A8A),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Next Follow-up',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white24,
                backgroundImage:
                    profilePictureUrl != null && profilePictureUrl!.isNotEmpty
                    ? NetworkImage(profilePictureUrl!)
                    : null,
                child: profilePictureUrl == null || profilePictureUrl!.isEmpty
                    ? const Icon(Icons.person, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patientName?.isNotEmpty == true
                          ? patientName!
                          : 'No follow-up scheduled',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      note?.isNotEmpty == true
                          ? note!
                          : 'Create a prescription with next visit details to see it here.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    ),
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

class _ActivityItemData {
  const _ActivityItemData({
    required this.title,
    required this.subtitle,
    required this.timeAgo,
    required this.icon,
    required this.color,
    required this.iconColor,
  });

  final String title;
  final String subtitle;
  final String timeAgo;
  final IconData icon;
  final Color color;
  final Color iconColor;
}
