import 'package:flutter/material.dart';

import '../../widgets/common/dashboard_shell.dart';

class LabSettingsPage extends StatefulWidget {
  const LabSettingsPage({super.key});

  @override
  State<LabSettingsPage> createState() => _LabSettingsPageState();
}

class _LabSettingsPageState extends State<LabSettingsPage> {
  bool _emailAlerts = true;
  bool _urgentOnly = false;
  bool _autoRefresh = true;

  @override
  Widget build(BuildContext context) {
    return DashboardShell(
      child: ListView(
        children: [
          Text(
            'Settings',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Email Alerts'),
                  subtitle: const Text(
                    'Receive upload and queue notifications',
                  ),
                  value: _emailAlerts,
                  onChanged: (v) => setState(() => _emailAlerts = v),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Urgent Cases First'),
                  subtitle: const Text(
                    'Prioritize urgent tests in default queues',
                  ),
                  value: _urgentOnly,
                  onChanged: (v) => setState(() => _urgentOnly = v),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Auto Refresh Dashboard'),
                  subtitle: const Text('Keep dashboard widgets synced'),
                  value: _autoRefresh,
                  onChanged: (v) => setState(() => _autoRefresh = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Settings saved locally.')),
                );
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save Settings'),
            ),
          ),
        ],
      ),
    );
  }
}
