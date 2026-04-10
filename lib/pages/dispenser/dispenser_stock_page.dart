import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../controllers/role_dashboard_controller.dart';
import '../../widgets/common/app_data_table.dart';
import '../../widgets/common/dashboard_shell.dart';

class DispenserStockPage extends StatefulWidget {
  const DispenserStockPage({super.key});

  @override
  State<DispenserStockPage> createState() => _DispenserStockPageState();
}

class _DispenserStockPageState extends State<DispenserStockPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _lowStockOnly = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<RoleDashboardController>().loadDispenser();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<RoleDashboardController>();
    final all = c.dispenserStock;

    final lowStockCount = all
        .where((s) => s.currentQuantity <= s.minimumStock)
        .length;
    final totalUnits = all.fold<int>(
      0,
      (sum, item) => sum + item.currentQuantity,
    );

    final q = _searchCtrl.text.trim().toLowerCase();
    final filtered = all.where((s) {
      if (_lowStockOnly && s.currentQuantity > s.minimumStock) return false;
      if (q.isEmpty) return true;
      return s.itemName.toLowerCase().contains(q) ||
          s.categoryName.toLowerCase().contains(q) ||
          s.unit.toLowerCase().contains(q);
    }).toList();

    return DashboardShell(
      child: c.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Inventory Control',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Monitor medicine stock, identify low inventory, and prepare restocking.',
                            style: TextStyle(color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: () => context
                          .read<RoleDashboardController>()
                          .loadDispenser(),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Refresh'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/dispenser/dashboard'),
                      icon: const Icon(Icons.dashboard_outlined),
                      label: const Text('Dashboard'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 980;
                    return GridView.count(
                      crossAxisCount: wide ? 3 : 1,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: wide ? 2.2 : 3.2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _InventoryStatCard(
                          title: 'Tracked Items',
                          value: all.length.toString(),
                          subtitle: 'Inventory entries for dispenser role',
                          icon: Icons.medication_outlined,
                          tint: const Color(0xFF2563EB),
                        ),
                        _InventoryStatCard(
                          title: 'Low Stock Alerts',
                          value: lowStockCount.toString(),
                          subtitle: lowStockCount == 0
                              ? 'Everything above threshold'
                              : 'Needs restock planning',
                          icon: Icons.warning_amber_rounded,
                          tint: const Color(0xFFDC2626),
                        ),
                        _InventoryStatCard(
                          title: 'Total Units',
                          value: totalUnits.toString(),
                          subtitle: 'Combined current quantity',
                          icon: Icons.inventory_2_outlined,
                          tint: const Color(0xFF0F766E),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: 'Search item, category or unit...',
                                prefixIcon: const Icon(Icons.search),
                                border: const OutlineInputBorder(),
                                isDense: true,
                                suffixIcon: _searchCtrl.text.isEmpty
                                    ? null
                                    : IconButton(
                                        onPressed: () {
                                          _searchCtrl.clear();
                                          setState(() {});
                                        },
                                        icon: const Icon(Icons.clear),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          FilterChip(
                            selected: _lowStockOnly,
                            onSelected: (v) =>
                                setState(() => _lowStockOnly = v),
                            label: const Text('Low stock only'),
                            selectedColor: const Color(0xFFFFE4E6),
                            checkmarkColor: const Color(0xFF9F1239),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Showing ${filtered.length} of ${all.length} item(s)',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      AppDataTable(
                        columns: const [
                          DataColumn(label: Text('Item')),
                          DataColumn(label: Text('Category')),
                          DataColumn(label: Text('Current')),
                          DataColumn(label: Text('Minimum')),
                          DataColumn(label: Text('Coverage')),
                          DataColumn(label: Text('Status')),
                        ],
                        rows: filtered
                            .map(
                              (s) => DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      s.itemName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(s.categoryName)),
                                  DataCell(
                                    Text('${s.currentQuantity} ${s.unit}'),
                                  ),
                                  DataCell(Text('${s.minimumStock} ${s.unit}')),
                                  DataCell(
                                    SizedBox(
                                      width: 120,
                                      child: LinearProgressIndicator(
                                        value: s.minimumStock <= 0
                                            ? 1
                                            : (s.currentQuantity /
                                                      s.minimumStock)
                                                  .clamp(0, 1)
                                                  .toDouble(),
                                        minHeight: 8,
                                        borderRadius: BorderRadius.circular(
                                          100,
                                        ),
                                        backgroundColor: const Color(
                                          0xFFE2E8F0,
                                        ),
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              s.currentQuantity <=
                                                      s.minimumStock
                                                  ? const Color(0xFFDC2626)
                                                  : const Color(0xFF16A34A),
                                            ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            s.currentQuantity <= s.minimumStock
                                            ? const Color(0xFFFFE4E6)
                                            : const Color(0xFFDCFCE7),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        s.currentQuantity <= s.minimumStock
                                            ? 'Low Stock'
                                            : 'Healthy',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color:
                                              s.currentQuantity <=
                                                  s.minimumStock
                                              ? const Color(0xFF9F1239)
                                              : const Color(0xFF166534),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _InventoryStatCard extends StatelessWidget {
  const _InventoryStatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.tint,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 28,
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
              color: tint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: tint),
          ),
        ],
      ),
    );
  }
}
