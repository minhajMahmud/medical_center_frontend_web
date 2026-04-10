import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/role_dashboard_controller.dart';
import '../../widgets/common/dashboard_shell.dart';

class LabAnnouncementsPage extends StatefulWidget {
  const LabAnnouncementsPage({super.key});

  @override
  State<LabAnnouncementsPage> createState() => _LabAnnouncementsPageState();
}

class _LabAnnouncementsPageState extends State<LabAnnouncementsPage> {
  final _announcementCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<RoleDashboardController>().loadLab();
    });
  }

  @override
  void dispose() {
    _announcementCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<RoleDashboardController>();

    final recent = c.labHistory.take(6).toList();

    return DashboardShell(
      child: c.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Text(
                  'Announcements',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Post an update',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _announcementCtrl,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText:
                                'Write a notice for patients and doctors...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: () {
                              final text = _announcementCtrl.text.trim();
                              if (text.isEmpty) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Announcement queue added (UI ready).',
                                  ),
                                ),
                              );
                              _announcementCtrl.clear();
                            },
                            icon: const Icon(Icons.send_outlined),
                            label: const Text('Publish'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Recent Activity',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (recent.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('No recent items to announce.'),
                    ),
                  )
                else
                  ...recent.map(
                    (h) => Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.campaign_outlined),
                        ),
                        title: Text(h.testName ?? 'Lab Update'),
                        subtitle: Text(
                          'Result #${h.resultId} • ${h.patientName}',
                        ),
                        trailing: Text(
                          h.createdAt == null
                              ? '-'
                              : DateFormat('dd MMM').format(h.createdAt!),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
