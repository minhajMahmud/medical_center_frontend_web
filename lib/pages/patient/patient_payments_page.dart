import 'package:backend_client/backend_client.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/api_service.dart';
import '../../utils/receipt_print_service.dart';
import '../../widgets/common/dashboard_shell.dart';

class PatientPaymentsPage extends StatefulWidget {
  const PatientPaymentsPage({super.key});

  @override
  State<PatientPaymentsPage> createState() => _PatientPaymentsPageState();
}

class _PatientPaymentsPageState extends State<PatientPaymentsPage> {
  final _client = ApiService.instance.client;

  bool _loading = true;
  bool _paying = false;
  String _selectedMethod = 'bKash';
  List<LabPaymentItem> _items = <LabPaymentItem>[];

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    setState(() => _loading = true);
    try {
      final items = await _client.patient.getMyLabPaymentItems();
      if (!mounted) return;
      setState(() => _items = items);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load payment data: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _payBill(LabPaymentItem item) async {
    setState(() => _paying = true);
    try {
      final updated = await _client.patient.payMyLabBill(
        resultId: item.resultId,
        paymentMethod: _selectedMethod,
      );
      if (!mounted) return;
      if (updated == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment failed. Please try again.')),
        );
        return;
      }
      await _loadPayments();
      if (!mounted) return;
      _showReceipt(updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Payment failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _paying = false);
      }
    }
  }

  void _showReceipt(LabPaymentItem item) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(child: _PatientReceiptDialog(item: item)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingBills = _items
        .where((item) => item.paymentStatus != 'PAID')
        .toList();
    final completedBills = _items
        .where((item) => item.paymentStatus == 'PAID')
        .toList();
    final outstanding = pendingBills.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );

    return DashboardShell(
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Row(
                  children: [
                    Text(
                      'Payment Dashboard',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    _PaymentMethodChip(
                      label: _selectedMethod,
                      color: const Color(0xFF0D9488),
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
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _PatientSummary(
                          title: 'Pending Bills',
                          value: '${pendingBills.length}',
                          color: const Color(0xFFF59E0B),
                        ),
                        _PatientSummary(
                          title: 'Completed Payments',
                          value: '${completedBills.length}',
                          color: const Color(0xFF10B981),
                        ),
                        _PatientSummary(
                          title: 'Outstanding',
                          value: '৳ ${outstanding.toStringAsFixed(0)}',
                          color: const Color(0xFF2563EB),
                        ),
                        const SizedBox(width: 16),
                        ...['bKash', 'Nagad', 'Rocket', 'Visa Card'].map(
                          (method) => ChoiceChip(
                            selected: _selectedMethod == method,
                            label: Text(method),
                            onSelected: (_) {
                              setState(() => _selectedMethod = method);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _PatientSection(
                  title: 'Pending Bills',
                  subtitle:
                      'Pay via bKash, Nagad, Rocket, or Visa card. Once payment succeeds, the bill moves to completed automatically.',
                  child: pendingBills.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No pending bills right now.'),
                        )
                      : Column(
                          children: [
                            const _PatientPaymentHeader(),
                            ...pendingBills.map(
                              (item) => _PatientPaymentRow(
                                item: item,
                                selectedMethod: _selectedMethod,
                                busy: _paying,
                                onPayNow: () => _payBill(item),
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 18),
                _PatientSection(
                  title: 'Completed / Receipt History',
                  subtitle:
                      'Every successful payment keeps a copy with test details, payment method, transaction ID, and payment date.',
                  child: completedBills.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Your completed payment history will appear here.',
                          ),
                        )
                      : Column(
                          children: [
                            const _PatientCompletedHeader(),
                            ...completedBills.map(
                              (item) => _PatientCompletedRow(
                                item: item,
                                onOpenReceipt: () => _showReceipt(item),
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

class _PaymentMethodChip extends StatelessWidget {
  const _PaymentMethodChip({required this.label, required this.color});

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
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _PatientSummary extends StatelessWidget {
  const _PatientSummary({
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Color(0xFF64748B))),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 24,
            ),
          ),
        ],
      ),
    );
  }
}

class _PatientSection extends StatelessWidget {
  const _PatientSection({
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

class _PatientPaymentHeader extends StatelessWidget {
  const _PatientPaymentHeader();

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
            flex: 28,
            child: Text(
              'Bill Details',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            flex: 14,
            child: Text('Date', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          Expanded(
            flex: 14,
            child: Text(
              'Amount',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            flex: 24,
            child: Text(
              'Method',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            flex: 20,
            child: Text(
              'Action',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _PatientPaymentRow extends StatelessWidget {
  const _PatientPaymentRow({
    required this.item,
    required this.selectedMethod,
    required this.busy,
    required this.onPayNow,
  });

  final LabPaymentItem item;
  final String selectedMethod;
  final bool busy;
  final VoidCallback onPayNow;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 28,
            child: Text(
              '${item.testName}\n${item.patientName}\n${item.mobileNumber}',
            ),
          ),
          Expanded(
            flex: 14,
            child: Text(DateFormat('dd/MM/yyyy').format(item.createdAt)),
          ),
          Expanded(
            flex: 14,
            child: Text('৳ ${item.amount.toStringAsFixed(2)}'),
          ),
          Expanded(flex: 24, child: Text(selectedMethod)),
          Expanded(
            flex: 20,
            child: FilledButton.icon(
              onPressed: busy ? null : onPayNow,
              icon: const Icon(Icons.payments_outlined),
              label: Text(busy ? 'Processing...' : 'Pay Bill'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PatientCompletedHeader extends StatelessWidget {
  const _PatientCompletedHeader();

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
            flex: 24,
            child: Text(
              'Test / Patient',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            flex: 14,
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
            flex: 14,
            child: Text('Date', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          Expanded(
            flex: 12,
            child: Text(
              'Amount',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            flex: 18,
            child: Text(
              'Receipt',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _PatientCompletedRow extends StatelessWidget {
  const _PatientCompletedRow({required this.item, required this.onOpenReceipt});

  final LabPaymentItem item;
  final VoidCallback onOpenReceipt;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 24,
            child: Text('${item.testName}\n${item.patientName}'),
          ),
          Expanded(flex: 14, child: Text(item.paymentMethod ?? '-')),
          Expanded(flex: 18, child: Text(item.transactionId ?? '-')),
          Expanded(
            flex: 14,
            child: Text(
              item.paidAt == null
                  ? '-'
                  : DateFormat('dd/MM/yyyy').format(item.paidAt!),
            ),
          ),
          Expanded(
            flex: 12,
            child: Text('৳ ${item.amount.toStringAsFixed(2)}'),
          ),
          Expanded(
            flex: 18,
            child: OutlinedButton.icon(
              onPressed: onOpenReceipt,
              icon: const Icon(Icons.receipt_long_outlined, size: 16),
              label: const Text('Bill Copy'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PatientReceiptDialog extends StatelessWidget {
  const _PatientReceiptDialog({required this.item});

  final LabPaymentItem item;

  String _buildPrintableHtml() {
    final paidAtText = item.paidAt == null
        ? '-'
        : DateFormat('dd/MM/yyyy HH:mm').format(item.paidAt!);
    return buildNstuPaymentReceiptHtml(
      title: 'Bill Payment Copy',
      patientName: item.patientName,
      mobile: item.mobileNumber,
      testName: item.testName,
      paymentMethod: item.paymentMethod ?? '-',
      transactionId: item.transactionId ?? '-',
      paymentDate: paidAtText,
      amount: item.amount,
      footerNote: 'Printed from NSTU Medical Center patient payment dashboard.',
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
                const Text(
                  'Bill Payment Copy',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(),
            Text(
              'Patient: ${item.patientName}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text('Mobile: ${item.mobileNumber}'),
            Text('Test Details: ${item.testName}'),
            const SizedBox(height: 12),
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
                  Text('Payment Method: ${item.paymentMethod ?? '-'}'),
                  Text('Transaction ID: ${item.transactionId ?? '-'}'),
                  Text(
                    'Payment Date: ${item.paidAt == null ? '-' : DateFormat('dd/MM/yyyy • HH:mm').format(item.paidAt!)}',
                  ),
                  Text('Amount Paid: ৳ ${item.amount.toStringAsFixed(2)}'),
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
