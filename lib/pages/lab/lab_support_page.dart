import 'package:flutter/material.dart';

import '../../widgets/common/dashboard_shell.dart';

class LabSupportPage extends StatelessWidget {
  const LabSupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DashboardShell(
      child: ListView(
        children: [
          Text(
            'Support',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              leading: Icon(Icons.support_agent),
              title: Text('Live Support Desk'),
              subtitle: Text('Available 8:00 AM - 8:00 PM • +880 1700-000000'),
            ),
          ),
          const SizedBox(height: 8),
          const Card(
            child: ListTile(
              leading: Icon(Icons.email_outlined),
              title: Text('Email Assistance'),
              subtitle: Text('lab-support@nstu-medical.local'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ExpansionTile(
              title: const Text('How do I upload a pending test result?'),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: const [
                Text(
                  'Go to Upload, find pending items, and click Upload for the selected result. You can attach files or map generated reports in the next integration step.',
                ),
              ],
            ),
          ),
          Card(
            child: ExpansionTile(
              title: const Text('How to disable a test temporarily?'),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: const [
                Text(
                  'Open Manage Test and switch Availability off. You can also bulk deactivate from the table toolbar.',
                ),
              ],
            ),
          ),
          Card(
            child: ExpansionTile(
              title: const Text('Can I export monthly analytics?'),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: const [
                Text(
                  'Analytics and dashboard exports can be connected to backend reporting endpoints as a follow-up.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
