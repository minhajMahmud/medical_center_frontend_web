import 'package:backend_client/backend_client.dart';
import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../widgets/common/dashboard_shell.dart';

class LabManageTestPage extends StatefulWidget {
  const LabManageTestPage({super.key});

  @override
  State<LabManageTestPage> createState() => _LabManageTestPageState();
}

class _LabManageTestPageState extends State<LabManageTestPage> {
  final _client = ApiService.instance.client;

  bool _loading = true;
  String _search = '';

  final Set<int> _selectedIds = <int>{};
  List<LabTests> _tests = <LabTests>[];
  LabTests? _active;

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _studentFeeCtrl = TextEditingController();
  final _teacherFeeCtrl = TextEditingController();
  final _outsideFeeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchTests();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _studentFeeCtrl.dispose();
    _teacherFeeCtrl.dispose();
    _outsideFeeCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchTests() async {
    setState(() => _loading = true);
    try {
      final tests = await _client.lab.getAllLabTests();
      if (!mounted) return;
      setState(() {
        _tests = tests;
        _loading = false;
      });
      if (tests.isNotEmpty) {
        _setActive(tests.first);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load tests: $e')));
    }
  }

  void _setActive(LabTests test) {
    setState(() {
      _active = test;
      _nameCtrl.text = test.testName;
      _descCtrl.text = test.description;
      _studentFeeCtrl.text = test.studentFee.toStringAsFixed(1);
      _teacherFeeCtrl.text = test.teacherFee.toStringAsFixed(1);
      _outsideFeeCtrl.text = test.outsideFee.toStringAsFixed(1);
    });
  }

  Future<void> _updateAvailability(LabTests test, bool value) async {
    final updated = test.copyWith(available: value);
    setState(() {
      final idx = _tests.indexWhere((t) => t.id == test.id);
      if (idx >= 0) _tests[idx] = updated;
      if (_active?.id == test.id) _active = updated;
    });

    final ok = await _client.lab.updateLabTest(updated);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update availability')),
      );
      await _fetchTests();
    }
  }

  Future<void> _bulkDeactivate() async {
    if (_selectedIds.isEmpty) return;

    for (final id in _selectedIds) {
      final idx = _tests.indexWhere((t) => t.id == id);
      if (idx < 0) continue;
      final current = _tests[idx];
      if (!current.available) continue;
      final ok = await _client.lab.updateLabTest(
        current.copyWith(available: false),
      );
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to deactivate ${current.testName}')),
        );
      }
    }

    if (!mounted) return;
    _selectedIds.clear();
    await _fetchTests();
  }

  Future<void> _saveActive() async {
    final active = _active;
    if (active == null) return;

    final student = double.tryParse(_studentFeeCtrl.text.trim());
    final teacher = double.tryParse(_teacherFeeCtrl.text.trim());
    final outside = double.tryParse(_outsideFeeCtrl.text.trim());

    if (student == null || teacher == null || outside == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid fee numbers.')),
      );
      return;
    }

    final updated = active.copyWith(
      testName: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      studentFee: student,
      teacherFee: teacher,
      outsideFee: outside,
    );

    final ok = await _client.lab.updateLabTest(updated);
    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test updated successfully.')),
      );
      await _fetchTests();
      final refreshed = _tests
          .where((t) => t.id == updated.id)
          .cast<LabTests?>()
          .firstWhere((e) => e != null, orElse: () => updated);
      _setActive(refreshed!);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to save changes.')));
    }
  }

  Future<void> _openAddDialog() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final studentCtrl = TextEditingController();
    final teacherCtrl = TextEditingController();
    final outsideCtrl = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Test'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Test Name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: studentCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Student fee'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: teacherCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Staff fee'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: outsideCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Outside fee'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (created != true) return;

    final student = double.tryParse(studentCtrl.text.trim()) ?? 0;
    final teacher = double.tryParse(teacherCtrl.text.trim()) ?? 0;
    final outside = double.tryParse(outsideCtrl.text.trim()) ?? 0;

    final ok = await _client.lab.createLabTest(
      LabTests(
        testName: nameCtrl.text.trim(),
        description: descCtrl.text.trim(),
        studentFee: student,
        teacherFee: teacher,
        outsideFee: outside,
        available: true,
      ),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Test created.' : 'Failed to create test.')),
    );
    if (ok) await _fetchTests();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _tests.where((t) {
      if (_search.trim().isNotEmpty) {
        final q = _search.toLowerCase();
        if (!t.testName.toLowerCase().contains(q) &&
            !t.description.toLowerCase().contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();

    return DashboardShell(
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manage Test',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F1FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.notifications_none),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            onChanged: (v) => setState(() => _search = v),
                            decoration: InputDecoration(
                              hintText: 'Search tests...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        flex: 7,
                        child: Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Row(
                                  children: [
                                    FilledButton.icon(
                                      onPressed: _openAddDialog,
                                      icon: const Icon(Icons.add),
                                      label: const Text('Add New Test'),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton.icon(
                                      onPressed: _selectedIds.isEmpty
                                          ? null
                                          : _bulkDeactivate,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFFDC2626,
                                        ),
                                      ),
                                      icon: const Icon(Icons.delete_outline),
                                      label: const Text('Bulk Deactivate'),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1),
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SizedBox(
                                    width: 860,
                                    child: ListView.builder(
                                      itemCount: filtered.length + 1,
                                      itemBuilder: (context, index) {
                                        if (index == 0) {
                                          return const _ManageHeaderRow();
                                        }
                                        final t = filtered[index - 1];
                                        final checked =
                                            t.id != null &&
                                            _selectedIds.contains(t.id);
                                        final selected = _active?.id == t.id;

                                        return InkWell(
                                          onTap: () => _setActive(t),
                                          child: Container(
                                            color: selected
                                                ? const Color(0xFFE8F1FF)
                                                : (index.isEven
                                                      ? const Color(0xFFF8FAFC)
                                                      : Colors.white),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 10,
                                            ),
                                            child: Row(
                                              children: [
                                                SizedBox(
                                                  width: 34,
                                                  child: Checkbox(
                                                    value: checked,
                                                    onChanged: (v) {
                                                      if (t.id == null) return;
                                                      setState(() {
                                                        if (v == true) {
                                                          _selectedIds.add(
                                                            t.id!,
                                                          );
                                                        } else {
                                                          _selectedIds.remove(
                                                            t.id!,
                                                          );
                                                        }
                                                      });
                                                    },
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: 200,
                                                  child: Text(t.testName),
                                                ),
                                                SizedBox(
                                                  width: 110,
                                                  child: Text(
                                                    t.studentFee
                                                        .toStringAsFixed(1),
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: 110,
                                                  child: Text(
                                                    t.teacherFee
                                                        .toStringAsFixed(1),
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: 110,
                                                  child: Text(
                                                    t.outsideFee
                                                        .toStringAsFixed(1),
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: 130,
                                                  child: Align(
                                                    alignment:
                                                        Alignment.centerLeft,
                                                    child: Switch(
                                                      value: t.available,
                                                      onChanged: (v) =>
                                                          _updateAvailability(
                                                            t,
                                                            v,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Edit Test: ${_active?.testName ?? '-'}',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _nameCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Test Name',
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _descCtrl,
                                  maxLines: 2,
                                  decoration: const InputDecoration(
                                    labelText: 'Description',
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _studentFeeCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Student (taka)',
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _teacherFeeCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Staff (taka)',
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _outsideFeeCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Outside (taka)',
                                  ),
                                ),
                                const Spacer(),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: _active == null
                                        ? null
                                        : _saveActive,
                                    child: const Text('Save Changes'),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: _active == null
                                        ? null
                                        : () => _setActive(_active!),
                                    child: const Text('Cancel'),
                                  ),
                                ),
                              ],
                            ),
                          ),
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

class _ManageHeaderRow extends StatelessWidget {
  const _ManageHeaderRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF1F5F9),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: const Row(
        children: [
          SizedBox(width: 34),
          SizedBox(
            width: 200,
            child: Text(
              'Test Name',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(
            width: 110,
            child: Text(
              'Student Fee (৳)',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(
            width: 110,
            child: Text(
              'Staff Fee (৳)',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(
            width: 110,
            child: Text(
              'Outside Fee (৳)',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(
            width: 130,
            child: Text(
              'Availability',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
