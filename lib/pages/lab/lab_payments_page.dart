import 'package:backend_client/backend_client.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/api_service.dart';
import '../../utils/receipt_print_service.dart';
import '../../widgets/common/dashboard_shell.dart';

class LabPaymentsPage extends StatefulWidget {
  const LabPaymentsPage({super.key});

  @override
  State<LabPaymentsPage> createState() => _LabPaymentsPageState();
}

class _LabPaymentsPageState extends State<LabPaymentsPage> {
  final _client = ApiService.instance.client;

  bool _loading = true;
  bool _busy = false;
  String _search = '';
  List<LabPaymentItem> _items = <LabPaymentItem>[];

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    setState(() => _loading = true);
    try {
      final items = await _client.lab.getLabPaymentItems();
      if (!mounted) return;
      setState(() => _items = items);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load lab payments: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allBills = _items.map((item) => item).where((bill) {
      if (_search.trim().isEmpty) return true;
      final q = _search.toLowerCase();
      return bill.patientName.toLowerCase().contains(q) ||
          bill.mobileNumber.toLowerCase().contains(q) ||
          bill.testName.toLowerCase().contains(q) ||
          bill.serialNo.toLowerCase().contains(q);
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final pendingBills = allBills
        .where((bill) => bill.paymentStatus != 'PAID')
        .toList();
    final paidBills = allBills
        .where((bill) => bill.paymentStatus == 'PAID')
        .toList();

    final todayCash = paidBills.fold<double>(
      0,
      (sum, payment) => sum + payment.amount,
    );

    return DashboardShell(
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Row(
                  children: [
                    Text(
                      'Lab Payment Center',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    _HeaderChip(
                      icon: Icons.payments_outlined,
                      label: 'Cash Desk Active',
                      color: const Color(0xFF0D9488),
                    ),
                    const SizedBox(width: 10),
                    _HeaderChip(
                      icon: Icons.receipt_long_outlined,
                      label: 'Paid Today: ৳ ${todayCash.toStringAsFixed(0)}',
                      color: const Color(0xFF2563EB),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            onChanged: (value) =>
                                setState(() => _search = value),
                            decoration: InputDecoration(
                              hintText:
                                  'Search patient, mobile, test name, serial...',
                              prefixIcon: const Icon(Icons.search),
                              isDense: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        _SummaryCard(
                          title: 'Pending Cash',
                          value: '${pendingBills.length}',
                          subtitle: 'Awaiting collection',
                          color: const Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 12),
                        _SummaryCard(
                          title: 'Collected',
                          value: '${paidBills.length}',
                          subtitle: 'Completed bills',
                          color: const Color(0xFF10B981),
                        ),
                        const SizedBox(width: 12),
                        _SummaryCard(
                          title: 'Printable Receipts',
                          value: '${paidBills.length}',
                          subtitle: 'Ready for print/PDF',
                          color: const Color(0xFF6366F1),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _SectionCard(
                  title: 'Tests Awaiting Cash Collection (Today)',
                  subtitle:
                      'Every created test appears here. Collect cash and issue paid receipt.',
                  child: pendingBills.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No pending payment rows right now.'),
                        )
                      : Column(
                          children: [
                            const _LabPaymentHeader(),
                            ...pendingBills.map(
                              (bill) => _LabPaymentRow(
                                bill: bill,
                                busy: _busy,
                                onCollectCash: () => _collectCash(bill),
                                onPrintReceipt: () => _showPaidReceipt(bill),
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 18),
                _SectionCard(
                  title: 'Completed Payments',
                  subtitle:
                      'Collected payments move here automatically with transaction details and receipt access.',
                  child: paidBills.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No completed payments yet.'),
                        )
                      : Column(
                          children: [
                            const _LabCompletedHeader(),
                            ...paidBills.map(
                              (bill) => _LabCompletedRow(
                                bill: bill,
                                busy: _busy,
                                onPrintReceipt: () => _showPaidReceipt(bill),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
    );
  }

  Future<void> _collectCash(LabPaymentItem bill) async {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Collect Cash: ${bill.patientName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Total'),
            const SizedBox(height: 8),
            Text(
              '৳ ${bill.amount.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text('${bill.testName} • ${bill.serialNo}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _busy
                ? null
                : () async {
                    Navigator.pop(dialogContext);
                    setState(() => _busy = true);
                    try {
                      final updated = await _client.lab.collectCashPayment(
                        resultId: bill.resultId,
                      );
                      await _loadPayments();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Cash payment collected (${updated?.transactionId ?? 'completed'}).',
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Cash collection failed: $e')),
                      );
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            child: const Text('Confirm Cash Collection'),
          ),
        ],
      ),
    );
  }

  void _showPaidReceipt(LabPaymentItem bill) {
    if (bill.paymentStatus != 'PAID') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Paid receipt becomes available after cash collection.',
          ),
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: _PaymentReceiptDialog(
          title: 'Paid Receipt',
          patientName: bill.patientName,
          mobile: bill.mobileNumber,
          testName: bill.testName,
          amount: bill.amount,
          transactionId: bill.transactionId ?? '-',
          paymentMethod: bill.paymentMethod ?? '-',
          paidAt: bill.paidAt ?? bill.createdAt,
        ),
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  final String title;
  final String value;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 8),
            color: Colors.black.withValues(alpha: 0.04),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Color(0xFF475569))),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Color(0xFF64748B))),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Color(0xFF64748B))),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _LabPaymentHeader extends StatelessWidget {
  const _LabPaymentHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Expanded(
            flex: 26,
            child: Text(
              'Patient Details',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            flex: 13,
            child: Text(
              'Test Type',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            flex: 12,
            child: Text(
              'Total Due (৳)',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            flex: 13,
            child: Text(
              'Created At',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            flex: 26,
            child: Text(
              'Actions',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _LabPaymentRow extends StatelessWidget {
  const _LabPaymentRow({
    required this.bill,
    required this.busy,
    required this.onCollectCash,
    required this.onPrintReceipt,
  });

  final LabPaymentItem bill;
  final bool busy;
  final VoidCallback onCollectCash;
  final VoidCallback onPrintReceipt;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 26,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${bill.patientName}\n',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  TextSpan(
                    text: 'ID: ${bill.serialNo}\n',
                    style: const TextStyle(color: Color(0xFF334155)),
                  ),
                  TextSpan(
                    text: 'Mobile: ${bill.mobileNumber}',
                    style: const TextStyle(color: Color(0xFF334155)),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 13,
            child: Text('${bill.testName}\n${bill.patientType}'),
          ),
          Expanded(
            flex: 12,
            child: Text('৳ ${bill.amount.toStringAsFixed(2)}'),
          ),
          Expanded(
            flex: 13,
            child: Text(
              DateFormat('HH:mm:ss\ndd/MM/yyyy').format(bill.createdAt),
            ),
          ),
          Expanded(
            flex: 26,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: 132,
                  child: FilledButton(
                    onPressed: busy ? null : onCollectCash,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                    ),
                    child: const Text('Collect Cash'),
                  ),
                ),
                SizedBox(
                  width: 132,
                  child: OutlinedButton.icon(
                    onPressed: bill.paymentStatus != 'PAID'
                        ? null
                        : onPrintReceipt,
                    icon: const Icon(Icons.receipt_long_outlined, size: 16),
                    label: const Text('Paid Receipt'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LabCompletedHeader extends StatelessWidget {
  const _LabCompletedHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Expanded(
            flex: 25,
            child: Text(
              'Patient/Test',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            flex: 12,
            child: Text(
              'Method',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            flex: 18,
            child: Text(
              'Transaction',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            flex: 12,
            child: Text(
              'Paid At',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            flex: 10,
            child: Text(
              'Amount',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            flex: 23,
            child: Text(
              'Status / Actions',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _LabCompletedRow extends StatelessWidget {
  const _LabCompletedRow({
    required this.bill,
    required this.busy,
    required this.onPrintReceipt,
  });

  final LabPaymentItem bill;
  final bool busy;
  final VoidCallback onPrintReceipt;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 25,
            child: Text('${bill.patientName}\n${bill.testName}'),
          ),
          Expanded(flex: 12, child: Text(bill.paymentMethod ?? '-')),
          Expanded(flex: 18, child: Text(bill.transactionId ?? '-')),
          Expanded(
            flex: 12,
            child: Text(
              DateFormat(
                'HH:mm\ndd/MM/yyyy',
              ).format(bill.paidAt ?? bill.createdAt),
            ),
          ),
          Expanded(
            flex: 10,
            child: Text('৳ ${bill.amount.toStringAsFixed(0)}'),
          ),
          Expanded(
            flex: 23,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onPrintReceipt,
                  icon: const Icon(Icons.print_outlined, size: 16),
                  label: const Text('Print / Save PDF'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentReceiptDialog extends StatelessWidget {
  const _PaymentReceiptDialog({
    required this.title,
    required this.patientName,
    required this.mobile,
    required this.testName,
    required this.amount,
    required this.transactionId,
    required this.paymentMethod,
    required this.paidAt,
  });

  final String title;
  final String patientName;
  final String mobile;
  final String testName;
  final double amount;
  final String transactionId;
  final String paymentMethod;
  final DateTime paidAt;

  String _buildPrintableHtml() {
    final paidText = DateFormat('dd/MM/yyyy HH:mm').format(paidAt);
    return buildNstuPaymentReceiptHtml(
      title: title,
      patientName: patientName,
      mobile: mobile,
      testName: testName,
      paymentMethod: paymentMethod,
      transactionId: transactionId,
      paymentDate: paidText,
      amount: amount,
      footerNote: 'Printed from NSTU Medical Center lab payment center.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 520,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Patient: $patientName',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text('Mobile: $mobile'),
            Text('Test: $testName'),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Payment Method: $paymentMethod'),
                  Text('Transaction ID: $transactionId'),
                  Text(
                    'Payment Date: ${DateFormat('dd/MM/yyyy • HH:mm').format(paidAt)}',
                  ),
                  Text('Amount: ৳ ${amount.toStringAsFixed(2)}'),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () {
                  printReceiptHtml(_buildPrintableHtml());
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.print_outlined),
                label: const Text('Print / Save PDF'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
