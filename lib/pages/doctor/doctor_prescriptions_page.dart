import 'package:backend_client/backend_client.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/role_dashboard_controller.dart';
import '../../widgets/common/dashboard_shell.dart';

class _DoctorAppointmentsColors {
  static const Color pageTitle = Color(0xFF111827);
  static const Color body = Color(0xFF64748B);
  static const Color panel = Color(0xFFFFFFFF);
  static const Color panelSoft = Color(0xFFF8FAFC);
  static const Color panelBorder = Color(0xFFE2E8F0);
  static const Color primary = Color(0xFF2563EB);
  static const Color primarySoft = Color(0xFFEFF6FF);
  static const Color success = Color(0xFF22C55E);
  static const Color danger = Color(0xFFEF4444);
}

class DoctorPrescriptionsPage extends StatefulWidget {
  const DoctorPrescriptionsPage({super.key});

  @override
  State<DoctorPrescriptionsPage> createState() =>
      _DoctorPrescriptionsPageState();
}

class _DoctorPrescriptionsPageState extends State<DoctorPrescriptionsPage> {
  int _selectedTab = 0;
  String _searchQuery = '';
  final Set<int> _busyRequestIds = <int>{};

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<RoleDashboardController>().loadDoctorAppointmentRequests();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<RoleDashboardController>();
    final all = c.doctorAppointmentRequests;
    final filtered = _filteredRequests(all);

    final pendingCount = all.where((r) => _status(r) == 'PENDING').length;
    final confirmedCount = all.where((r) => _status(r) == 'CONFIRMED').length;
    final declinedCount = all.where((r) => _status(r) == 'DECLINED').length;

    final desktop = MediaQuery.sizeOf(context).width >= 1150;

    return DashboardShell(
      child: c.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Appointment Requests',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: _DoctorAppointmentsColors.pageTitle,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _DoctorAppointmentsColors.primarySoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$pendingCount pending',
                        style: const TextStyle(
                          color: _DoctorAppointmentsColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                desktop
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: _buildMainPanel(
                              requests: filtered,
                              pendingCount: pendingCount,
                              confirmedCount: confirmedCount,
                              declinedCount: declinedCount,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: _buildRightPanel(
                              all: all,
                              current: filtered,
                              pendingCount: pendingCount,
                              confirmedCount: confirmedCount,
                              declinedCount: declinedCount,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          _buildMainPanel(
                            requests: filtered,
                            pendingCount: pendingCount,
                            confirmedCount: confirmedCount,
                            declinedCount: declinedCount,
                          ),
                          const SizedBox(height: 16),
                          _buildRightPanel(
                            all: all,
                            current: filtered,
                            pendingCount: pendingCount,
                            confirmedCount: confirmedCount,
                            declinedCount: declinedCount,
                          ),
                        ],
                      ),
              ],
            ),
    );
  }

  String _status(AppointmentRequestItem item) =>
      item.status.trim().toUpperCase();

  List<AppointmentRequestItem> _filteredRequests(
    List<AppointmentRequestItem> all,
  ) {
    final tabStatus = switch (_selectedTab) {
      0 => 'PENDING',
      1 => 'CONFIRMED',
      _ => 'DECLINED',
    };

    return all.where((item) {
      if (_status(item) != tabStatus) return false;

      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase();

      return item.patientName.toLowerCase().contains(q) ||
          item.reason.toLowerCase().contains(q) ||
          item.patientPhone.toLowerCase().contains(q);
    }).toList();
  }

  Widget _buildMainPanel({
    required List<AppointmentRequestItem> requests,
    required int pendingCount,
    required int confirmedCount,
    required int declinedCount,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _DoctorAppointmentsColors.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _DoctorAppointmentsColors.panelBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _tabButton('Pending ($pendingCount)', 0),
                const SizedBox(width: 8),
                _tabButton('Confirmed ($confirmedCount)', 1),
                const SizedBox(width: 8),
                _tabButton('Declined ($declinedCount)', 2),
                const Spacer(),
                SizedBox(
                  width: 260,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search appointments...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      isDense: true,
                      filled: true,
                      fillColor: _DoctorAppointmentsColors.panelSoft,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: _DoctorAppointmentsColors.panelBorder,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: _DoctorAppointmentsColors.panelBorder,
                        ),
                      ),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (requests.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 36,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  color: _DoctorAppointmentsColors.panelSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _DoctorAppointmentsColors.panelBorder,
                  ),
                ),
                child: const Text('No appointments found for this filter.'),
              )
            else
              ...requests.map(_requestCard),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F7FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Text(
                'Declining a request should include a reason and suggested alternate slot to maintain better patient satisfaction.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _DoctorAppointmentsColors.body,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _requestCard(AppointmentRequestItem item) {
    final status = _status(item);
    final busy = _busyRequestIds.contains(item.appointmentRequestId);
    final date = item.appointmentDate;
    final timeRange = _timeRange(item.appointmentTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _DoctorAppointmentsColors.panelBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFE5EDFF),
            child: Text(
              item.patientName
                  .trim()
                  .split(' ')
                  .where((e) => e.isNotEmpty)
                  .take(2)
                  .map((e) => e[0])
                  .join()
                  .toUpperCase(),
              style: const TextStyle(
                color: _DoctorAppointmentsColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.patientName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _DoctorAppointmentsColors.pageTitle,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.patientPhone,
                  style: const TextStyle(
                    color: _DoctorAppointmentsColors.body,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              '${DateFormat('MMM d, yyyy').format(date)}\n$timeRange',
              style: const TextStyle(
                color: _DoctorAppointmentsColors.body,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.reason,
                  style: const TextStyle(
                    color: _DoctorAppointmentsColors.pageTitle,
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                ),
                if (item.urgent) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Urgent',
                      style: TextStyle(
                        color: _DoctorAppointmentsColors.danger,
                        fontWeight: FontWeight.w700,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _actionButtons(item, status: status, busy: busy),
        ],
      ),
    );
  }

  String _timeRange(String appointmentTime) {
    final now = DateTime.now();
    DateTime start;
    try {
      start = DateFormat('HH:mm').parse(appointmentTime);
    } catch (_) {
      try {
        start = DateFormat('HH:mm:ss').parse(appointmentTime);
      } catch (_) {
        return appointmentTime;
      }
    }
    final startDt = DateTime(
      now.year,
      now.month,
      now.day,
      start.hour,
      start.minute,
    );
    final endDt = startDt.add(const Duration(minutes: 30));
    return '${DateFormat('hh:mm a').format(startDt)} - ${DateFormat('hh:mm a').format(endDt)}';
  }

  Widget _actionButtons(
    AppointmentRequestItem item, {
    required String status,
    required bool busy,
  }) {
    if (status != 'PENDING') {
      final isConfirmed = status == 'CONFIRMED';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isConfirmed
              ? const Color(0xFFECFDF3)
              : const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          isConfirmed ? 'Confirmed' : 'Declined',
          style: TextStyle(
            color: isConfirmed
                ? _DoctorAppointmentsColors.success
                : _DoctorAppointmentsColors.danger,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      children: [
        SizedBox(
          height: 34,
          child: FilledButton(
            onPressed: busy
                ? null
                : () => _setStatus(item: item, status: 'CONFIRMED'),
            style: FilledButton.styleFrom(
              backgroundColor: _DoctorAppointmentsColors.success,
              foregroundColor: Colors.white,
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: const Text('Confirm'),
          ),
        ),
        SizedBox(
          height: 34,
          child: OutlinedButton(
            onPressed: busy
                ? null
                : () => _setStatus(item: item, status: 'DECLINED'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _DoctorAppointmentsColors.danger,
              side: const BorderSide(color: Color(0xFFFCA5A5)),
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: const Text('Decline'),
          ),
        ),
      ],
    );
  }

  Future<void> _setStatus({
    required AppointmentRequestItem item,
    required String status,
  }) async {
    String? declineReason;
    if (status == 'DECLINED') {
      declineReason = await _askDeclineReason();
      if (declineReason == null) return;
    }

    if (!mounted) return;

    setState(() {
      _busyRequestIds.add(item.appointmentRequestId);
    });

    final ok = await context
        .read<RoleDashboardController>()
        .updateDoctorAppointmentRequestStatus(
          appointmentRequestId: item.appointmentRequestId,
          status: status,
          declineReason: declineReason,
        );

    if (!mounted) return;

    setState(() {
      _busyRequestIds.remove(item.appointmentRequestId);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Request #${item.appointmentRequestId} ${status.toLowerCase()}.'
              : 'Could not update request #${item.appointmentRequestId}.',
        ),
      ),
    );
  }

  Future<String?> _askDeclineReason() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Decline appointment'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Reason for decline (optional)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Decline'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }

  Widget _tabButton(String label, int index) {
    final selected = _selectedTab == index;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? _DoctorAppointmentsColors.primarySoft
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? const Color(0xFFBFDBFE)
                : _DoctorAppointmentsColors.panelBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? _DoctorAppointmentsColors.primary
                : _DoctorAppointmentsColors.body,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildRightPanel({
    required List<AppointmentRequestItem> all,
    required List<AppointmentRequestItem> current,
    required int pendingCount,
    required int confirmedCount,
    required int declinedCount,
  }) {
    final sorted = [...all]
      ..sort((a, b) {
        final dateCompare = a.appointmentDate.compareTo(b.appointmentDate);
        if (dateCompare != 0) return dateCompare;
        return a.appointmentTime.compareTo(b.appointmentTime);
      });

    final upcoming = sorted.take(4).toList();
    final completedRate = all.isEmpty
        ? 0
        : ((confirmedCount / all.length) * 100).round();

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _DoctorAppointmentsColors.panel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _DoctorAppointmentsColors.panelBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Today\'s Schedule',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: _DoctorAppointmentsColors.pageTitle,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('MMM d, yyyy').format(DateTime.now()),
                style: const TextStyle(
                  color: _DoctorAppointmentsColors.body,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              if (upcoming.isEmpty)
                const Text('No schedule items.')
              else
                ...upcoming.map((item) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _DoctorAppointmentsColors.panelSoft,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _DoctorAppointmentsColors.panelBorder,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _timeRange(item.appointmentTime),
                          style: const TextStyle(
                            color: _DoctorAppointmentsColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.patientName,
                          style: const TextStyle(
                            color: _DoctorAppointmentsColors.pageTitle,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          item.mode,
                          style: const TextStyle(
                            color: _DoctorAppointmentsColors.body,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _DoctorAppointmentsColors.panel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _DoctorAppointmentsColors.panelBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quick Stats',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _statTile(
                      '${current.length}',
                      _selectedTab == 0
                          ? 'Pending now'
                          : _selectedTab == 1
                          ? 'Confirmed'
                          : 'Declined',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: _statTile('$completedRate%', 'Success rate')),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'All: $pendingCount pending • $confirmedCount confirmed • $declinedCount declined',
                style: const TextStyle(
                  color: _DoctorAppointmentsColors.body,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statTile(String value, String label) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _DoctorAppointmentsColors.panelSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _DoctorAppointmentsColors.panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: _DoctorAppointmentsColors.pageTitle,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: _DoctorAppointmentsColors.body,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}
