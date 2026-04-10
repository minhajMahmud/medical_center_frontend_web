import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:backend_client/backend_client.dart';

import '../../controllers/role_dashboard_controller.dart';
import '../../widgets/common/app_data_table.dart';
import '../../widgets/common/dashboard_shell.dart';

class DispenserDashboardPage extends StatefulWidget {
  const DispenserDashboardPage({super.key});

  @override
  State<DispenserDashboardPage> createState() => _DispenserDashboardPageState();
}

class _DispenserDashboardPageState extends State<DispenserDashboardPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<RoleDashboardController>().loadDispenser();
    });
  }

  String _firstName(String? fullName) {
    final trimmed = (fullName ?? '').trim();
    if (trimmed.isEmpty) return 'Dispenser';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  int _todayDispenseCount(RoleDashboardController c) {
    final now = DateTime.now();
    return c.dispenserHistory.where((h) {
      final d = h.dispensedAt;
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }).length;
  }

  String _recentMedicineLabel(DispenseHistoryEntry entry) {
    if (entry.items.isEmpty) return 'No medicine recorded';
    if (entry.items.length == 1) return entry.items.first.medicineName;
    return '${entry.items.first.medicineName} +${entry.items.length - 1} more';
  }

  int _totalUnits(DispenseHistoryEntry entry) {
    return entry.items.fold<int>(
      0,
      (int sum, DispensedItemSummary item) => sum + item.quantity,
    );
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color tint,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: tint),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<RoleDashboardController>();
    final profile = c.dispenserProfile;
    final lowStock = c.dispenserStock
        .where((s) => s.currentQuantity <= s.minimumStock)
        .toList();
    final todayDispenses = _todayDispenseCount(c);
    const dailyGoal = 10;
    final dailyProgress = (todayDispenses / dailyGoal).clamp(0, 1).toDouble();
    final dailyProgressPercent = (dailyProgress * 100).round();
    final lowStockNames = lowStock.take(2).map((e) => e.itemName).join(', ');

    return DashboardShell(
      child: c.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back, ${_firstName(profile?.name)}',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Here is an overview of dispensing and stock updates.',
                            style: TextStyle(color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: () => context.go('/dispenser/history'),
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Start New Dispensing'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/dispenser/stock'),
                      icon: const Icon(Icons.inventory_2_outlined),
                      label: const Text('Check Inventory'),
                    ),
                  ],
                ),
                if (c.error != null && c.error!.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFDA4AF)),
                    ),
                    child: Text(
                      c.error!,
                      style: const TextStyle(color: Color(0xFF9F1239)),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 1100;
                    final medium = constraints.maxWidth >= 700;
                    final columns = wide
                        ? 3
                        : medium
                        ? 2
                        : 1;
                    return GridView.count(
                      crossAxisCount: columns,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.9,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _kpiCard(
                          title: 'TOTAL DISPENSE RECORDS',
                          value: c.dispenserHistory.length.toString(),
                          subtitle: 'Recent records loaded from backend',
                          icon: Icons.receipt_long_outlined,
                          tint: const Color(0xFF1D4ED8),
                        ),
                        _kpiCard(
                          title: 'AVAILABLE STOCK ITEMS',
                          value: c.dispenserStock.length.toString(),
                          subtitle: 'Medicines currently tracked',
                          icon: Icons.medication_outlined,
                          tint: const Color(0xFF0D9488),
                        ),
                        _kpiCard(
                          title: 'LOW STOCK ALERTS',
                          value: lowStock.length.toString(),
                          subtitle: lowStock.isEmpty
                              ? 'No low-stock items right now'
                              : 'Needs review: $lowStockNames',
                          icon: Icons.warning_amber_rounded,
                          tint: const Color(0xFFDC2626),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Recently Dispensed Medications',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.go('/dispenser/history'),
                            child: const Text('View All Records'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      AppDataTable(
                        columns: const [
                          DataColumn(label: Text('Medication')),
                          DataColumn(label: Text('Patient')),
                          DataColumn(label: Text('Time')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Quantity')),
                        ],
                        rows: c.dispenserHistory.take(8).map((h) {
                          final patientLabel = h.patientId == null
                              ? h.patientName
                              : '#P-${h.patientId}';
                          return DataRow(
                            cells: [
                              DataCell(Text(_recentMedicineLabel(h))),
                              DataCell(Text(patientLabel)),
                              DataCell(
                                Text(
                                  DateFormat('hh:mm a').format(h.dispensedAt),
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    'Completed',
                                    style: TextStyle(
                                      color: Color(0xFF166534),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(Text('${_totalUnits(h)} unit(s)')),
                            ],
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 860;
                    final cards = [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Daily Goal Progress',
                                style: TextStyle(
                                  color: Color(0xFF1D4ED8),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '$dailyProgressPercent% Completed',
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 30,
                                ),
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: dailyProgress,
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(100),
                                backgroundColor: const Color(0xFFDBEAFE),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF2563EB),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$todayDispenses dispenses today (goal $dailyGoal)',
                                style: const TextStyle(
                                  color: Color(0xFF475569),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (isWide)
                        const SizedBox(width: 12)
                      else
                        const SizedBox(height: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDFA),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF99F6E4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Restock Recommendation',
                                style: TextStyle(
                                  color: Color(0xFF0F766E),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                lowStock.isEmpty
                                    ? 'Stock looks healthy'
                                    : '${lowStock.length} item(s) need restock',
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 28,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                lowStock.isEmpty
                                    ? 'No critical alerts from current backend stock snapshot.'
                                    : 'Prioritize: ${lowStock.take(3).map((i) => i.itemName).join(', ')}',
                                style: const TextStyle(
                                  color: Color(0xFF475569),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: () => context.go('/dispenser/stock'),
                                icon: const Icon(Icons.local_shipping_outlined),
                                label: const Text('Review Stock'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ];

                    return isWide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: cards,
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: cards,
                          );
                  },
                ),
              ],
            ),
    );
  }
}
