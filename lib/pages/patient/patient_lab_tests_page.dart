import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/role_dashboard_controller.dart';
import '../../widgets/common/dashboard_shell.dart';

class PatientLabTestsPage extends StatefulWidget {
  const PatientLabTestsPage({super.key});

  @override
  State<PatientLabTestsPage> createState() => _PatientLabTestsPageState();
}

class _PatientLabTestsPageState extends State<PatientLabTestsPage> {
  static const _pageBg = Color(0xFFF8FAFC);
  static const _surface = Colors.white;
  static const _border = Color(0xFFE2E8F0);
  static const _primary = Color(0xFF2563EB);
  static const _textMuted = Color(0xFF64748B);

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
    final c = context.watch<RoleDashboardController>();
    final auth = context.watch<AuthController>();
    final tests = c.patientLabTests;
    final availableCount = tests.where((t) => t.available).length;
    final unavailableCount = tests.length - availableCount;
    final patientType = _normalizedPatientType(auth.role);
    final feeLabel = _feeLabelForType(patientType);

    return DashboardShell(
      child: c.isLoading && c.patientLabTests.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Container(
              color: _pageBg,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 14),
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Lab Test Availability',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF0F172A),
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Check currently available tests, fees, and service details before visiting the lab.',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: _textMuted),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    'Showing $feeLabel pricing for your profile',
                                    style: const TextStyle(
                                      color: _primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: c.isLoading
                                ? null
                                : () => c.loadPatient(),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Refresh'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _SummaryCard(
                            title: 'Total Tests',
                            value: tests.length.toString(),
                            color: const Color(0xFF2563EB),
                            icon: Icons.science_outlined,
                          ),
                          _SummaryCard(
                            title: 'Available',
                            value: availableCount.toString(),
                            color: const Color(0xFF059669),
                            icon: Icons.check_circle_outline,
                          ),
                          _SummaryCard(
                            title: 'Unavailable',
                            value: unavailableCount.toString(),
                            color: const Color(0xFFDC2626),
                            icon: Icons.cancel_outlined,
                          ),
                          _SummaryCard(
                            title: 'Pricing Tier',
                            value: feeLabel,
                            color: const Color(0xFF7C3AED),
                            icon: Icons.payments_outlined,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _border),
                          boxShadow: const [
                            BoxShadow(
                              color: Color.fromRGBO(15, 23, 42, 0.05),
                              blurRadius: 12,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: tests.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(28),
                                child: Center(
                                  child: Text(
                                    'No lab tests found at the moment.',
                                  ),
                                ),
                              )
                            : SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  horizontalMargin: 18,
                                  columnSpacing: 26,
                                  headingRowHeight: 50,
                                  dataRowMinHeight: 62,
                                  dataRowMaxHeight: 66,
                                  headingRowColor: WidgetStateProperty.all(
                                    const Color(0xFFF1F5F9),
                                  ),
                                  columns: const [
                                    DataColumn(
                                      label: Text(
                                        'TEST NAME',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF334155),
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'DESCRIPTION',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF334155),
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'STATUS',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF334155),
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'PRICE',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF334155),
                                        ),
                                      ),
                                    ),
                                  ],
                                  rows: tests
                                      .map(
                                        (t) => DataRow(
                                          cells: [
                                            DataCell(
                                              Row(
                                                children: [
                                                  const CircleAvatar(
                                                    radius: 16,
                                                    backgroundColor: Color(
                                                      0xFFE8F1FF,
                                                    ),
                                                    child: Icon(
                                                      Icons.biotech_outlined,
                                                      color: _primary,
                                                      size: 18,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Text(
                                                    t.testName,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Color(0xFF1E293B),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            DataCell(
                                              SizedBox(
                                                width: 420,
                                                child: Text(
                                                  t.description,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Color(0xFF475569),
                                                    height: 1.35,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              _AvailabilityBadge(
                                                available: t.available,
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                '৳ ${_feeForType(t, patientType).toStringAsFixed(0)}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF0F172A),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  String _normalizedPatientType(String? rawRole) {
    final role = (rawRole ?? '').trim().toUpperCase();
    if (role.contains('STAFF') || role.contains('TEACHER')) return 'STAFF';
    if (role.contains('OUTSIDE') || role.contains('PUBLIC')) return 'OUTSIDE';
    return 'STUDENT';
  }

  String _feeLabelForType(String patientType) {
    switch (patientType) {
      case 'STAFF':
        return 'Staff';
      case 'OUTSIDE':
        return 'Outside';
      default:
        return 'Student';
    }
  }

  double _feeForType(dynamic test, String patientType) {
    switch (patientType) {
      case 'STAFF':
        return test.teacherFee as double;
      case 'OUTSIDE':
        return test.outsideFee as double;
      default:
        return test.studentFee as double;
    }
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String title;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 230,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(title, style: const TextStyle(color: Color(0xFF64748B))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AvailabilityBadge extends StatelessWidget {
  const _AvailabilityBadge({required this.available});

  final bool available;

  @override
  Widget build(BuildContext context) {
    final bg = available ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);
    final fg = available ? const Color(0xFF166534) : const Color(0xFFB91C1C);
    final dot = available ? const Color(0xFF22C55E) : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: dot),
          const SizedBox(width: 7),
          Text(
            available ? 'Available' : 'Unavailable',
            style: TextStyle(color: fg, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
