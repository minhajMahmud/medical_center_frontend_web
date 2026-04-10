import 'package:flutter/material.dart';

class DashboardStats extends StatelessWidget {
  const DashboardStats({
    super.key,
    required this.doctorCount,
    required this.appointmentCount,
    required this.reportCount,
  });

  final int doctorCount;
  final int appointmentCount;
  final int reportCount;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _StatCard(
          title: 'Doctors',
          value: doctorCount.toString(),
          icon: Icons.medical_services,
        ),
        _StatCard(
          title: 'Appointments',
          value: appointmentCount.toString(),
          icon: Icons.calendar_today,
        ),
        _StatCard(
          title: 'Medical Reports',
          value: reportCount.toString(),
          icon: Icons.description,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 30),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: Theme.of(context).textTheme.headlineSmall),
                  Text(title),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
