import 'dart:async';
import 'dart:typed_data';

import 'package:backend_client/backend_client.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/role_dashboard_controller.dart';
import '../../services/api_service.dart';
import '../../utils/cloudinary_upload.dart';
import '../../utils/receipt_print_service.dart';
import '../../widgets/common/dashboard_shell.dart';

class LabUploadPage extends StatefulWidget {
  const LabUploadPage({super.key});

  @override
  State<LabUploadPage> createState() => _LabUploadPageState();
}

class _LabUploadPageState extends State<LabUploadPage> {
  final _client = ApiService.instance.client;

  String _sortBy = 'All';
  String _search = '';
  String _patientType = 'STUDENT';
  String _lookupQuery = '';
  bool _lookupLoading = false;
  bool _creating = false;
  bool _testsLoading = false;

  final _patientNameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController(text: '+8801');
  final _customFeeCtrl = TextEditingController();

  final Set<int> _selectedTestIds = <int>{};
  final List<_PatientCandidate> _patientMatches = <_PatientCandidate>[];
  List<LabTests> _fallbackTests = <LabTests>[];

  // Debounce timer for real-time search
  Timer? _searchDebounce;
  String? _lastSearchQuery;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<RoleDashboardController>().loadLab();
      _loadAvailableTestsFallback();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _patientNameCtrl.dispose();
    _mobileCtrl.dispose();
    _customFeeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<RoleDashboardController>();
    final effectiveTests = c.labAvailableTests.isNotEmpty
        ? c.labAvailableTests
        : _fallbackTests;

    final testNameById = <int, String>{
      for (final t in effectiveTests)
        if (t.id != null) t.id!: t.testName,
    };

    final pending = c.labResults.where((r) => r.submittedAt == null).toList();
    final completed = c.labResults.where((r) => r.submittedAt != null).toList();

    final filteredCompleted = completed.where((r) {
      if (_search.trim().isEmpty) return true;
      final q = _search.toLowerCase();
      return r.patientName.toLowerCase().contains(q) ||
          r.mobileNumber.toLowerCase().contains(q) ||
          (r.resultId?.toString().contains(q) ?? false) ||
          (testNameById[r.testId]?.toLowerCase().contains(q) ?? false);
    }).toList();

    if (_sortBy == 'Recent') {
      filteredCompleted.sort(
        (a, b) => (b.submittedAt ?? DateTime(2000)).compareTo(
          a.submittedAt ?? DateTime(2000),
        ),
      );
    } else if (_sortBy == 'Name') {
      filteredCompleted.sort(
        (a, b) =>
            a.patientName.toLowerCase().compareTo(b.patientName.toLowerCase()),
      );
    }

    final revenue = filteredCompleted.fold<double>(
      0,
      (sum, result) => sum + _feeForResult(result, effectiveTests),
    );

    return DashboardShell(
      child: c.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _buildHeader(),
                const SizedBox(height: 10),
                _buildCreateButton(),
                const SizedBox(height: 12),
                _buildCreateCard(effectiveTests, c.labResults),
                const SizedBox(height: 14),
                _buildPendingTitle(),
                const SizedBox(height: 8),
                _buildPendingTable(pending, testNameById),
                const SizedBox(height: 14),
                _buildCompletedHeader(completed.length, revenue),
                const SizedBox(height: 10),
                _buildSearchSortBar(),
                const SizedBox(height: 8),
                _buildCompletedTable(filteredCompleted, testNameById),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Lab Technician Portal',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            const Icon(Icons.shield, size: 18, color: Color(0xFF16A34A)),
            const SizedBox(width: 6),
            const Text('System Health'),
            const SizedBox(width: 14),
            const Icon(Icons.cloud_done, size: 18, color: Color(0xFF06B6D4)),
            const SizedBox(width: 6),
            Text(
              'Cloud Sync: ${DateFormat('d/M/yyyy').format(DateTime.now())}',
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Row(
          children: [
            Icon(Icons.home_outlined, size: 16, color: Color(0xFF64748B)),
            SizedBox(width: 4),
            Text('Home', style: TextStyle(color: Color(0xFF64748B))),
            SizedBox(width: 4),
            Text('›', style: TextStyle(color: Color(0xFF64748B))),
            SizedBox(width: 4),
            Text(
              'Upload Dashboard',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCreateButton() {
    return Align(
      child: FilledButton.icon(
        onPressed: () {
          setState(() {
            _selectedTestIds.clear();
            _patientNameCtrl.clear();
            _mobileCtrl.text = '+8801';
            _customFeeCtrl.clear();
            _patientType = 'STUDENT';
          });
        },
        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D9488)),
        icon: const Icon(Icons.add),
        label: const Text('Create New Entry'),
      ),
    );
  }

  Widget _buildCreateCard(List<LabTests> tests, List<TestResult> labResults) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create New Test',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: _onPatientSearchChanged,
                    decoration: const InputDecoration(
                      hintText: 'Search patient by name or phone (real-time)',
                      prefixIcon: Icon(Icons.person_search_outlined),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 40,
                  height: 40,
                  child: _lookupLoading
                      ? const Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () => setState(() {
                            _lookupQuery = '';
                            _patientMatches.clear();
                            _searchDebounce?.cancel();
                          }),
                          icon: const Icon(Icons.close),
                        ),
                ),
              ],
            ),
            if (_lookupQuery.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildLookupResultPanel(),
            ],
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _fieldBlock(
                    'Test Name',
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_testsLoading)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: LinearProgressIndicator(minHeight: 2),
                          ),
                        if (tests.isEmpty)
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'No tests loaded. Click refresh to load available tests.',
                                  style: TextStyle(color: Color(0xFF64748B)),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Reload tests',
                                onPressed: _testsLoading
                                    ? null
                                    : _loadAvailableTestsFallback,
                                icon: const Icon(Icons.refresh),
                              ),
                            ],
                          )
                        else
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: tests
                                .where((t) => t.available)
                                .take(12)
                                .map((t) {
                                  final id = t.id;
                                  final selected =
                                      id != null &&
                                      _selectedTestIds.contains(id);
                                  return FilterChip(
                                    selected: selected,
                                    label: Text(t.testName),
                                    onSelected: (value) {
                                      if (id == null) return;
                                      setState(() {
                                        if (value) {
                                          _selectedTestIds.add(id);
                                        } else {
                                          _selectedTestIds.remove(id);
                                        }
                                      });
                                    },
                                  );
                                })
                                .toList(),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: _fieldBlock(
                    'Patient Type',
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: ['STUDENT', 'STAFF', 'OUTSIDE'].map((type) {
                        return ChoiceChip(
                          selected: _patientType == type,
                          label: Text(type),
                          onSelected: (_) =>
                              setState(() => _patientType = type),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: _fieldBlock(
                    'Patient Name',
                    TextField(
                      controller: _patientNameCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Auto-search and create',
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: _fieldBlock(
                    'Mobile Number',
                    TextField(
                      controller: _mobileCtrl,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                SizedBox(
                  width: 250,
                  child: _fieldBlock(
                    'Custom Fee (Tk)',
                    TextField(
                      controller: _customFeeCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'Outside',
                        prefixIcon: Icon(Icons.payments_outlined),
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _selectedTestIds.clear();
                      _patientNameCtrl.clear();
                      _mobileCtrl.text = '+8801';
                      _customFeeCtrl.clear();
                      _patientType = 'STUDENT';
                    });
                  },
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                  ),
                  onPressed: _creating
                      ? null
                      : () => _createTestEntries(
                          context.read<RoleDashboardController>(),
                        ),
                  child: _creating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                  ),
                  onPressed: () => _openReceiptPreviewFromForm(tests),
                  child: const Text('Generate Receipt'),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _openReceiptPreviewFromForm(tests),
                  icon: const Icon(Icons.print_outlined),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLookupResultPanel() {
    if (_lookupLoading) {
      return const LinearProgressIndicator(minHeight: 2);
    }

    if (_patientMatches.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'No patient found in database. You can manually add name and phone.',
          style: TextStyle(color: Color(0xFF475569)),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 180),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _patientMatches.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final m = _patientMatches[index];
          return ListTile(
            dense: true,
            leading: const Icon(Icons.person_outline),
            title: Text(m.name),
            subtitle: Text('${m.phone} • ${m.source}'),
            trailing: FilledButton.tonal(
              onPressed: () {
                setState(() {
                  _patientNameCtrl.text = m.name;
                  _mobileCtrl.text = m.phone;
                  if (m.patientType != null && m.patientType!.isNotEmpty) {
                    _patientType = m.patientType!.toUpperCase();
                  }
                });
              },
              child: const Text('Use'),
            ),
          );
        },
      ),
    );
  }

  void _onPatientSearchChanged(String query) {
    setState(() => _lookupQuery = query);
    _searchDebounce?.cancel();

    if (query.trim().isEmpty) {
      setState(() => _patientMatches.clear());
      return;
    }

    _lastSearchQuery = query;
    setState(() => _lookupLoading = true);

    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (_lastSearchQuery != query) return; // User kept typing
      _searchPatientInDatabase();
    });
  }

  Future<void> _searchPatientInDatabase() async {
    final q = _lookupQuery.trim();
    if (q.isEmpty) return;

    final controller = context.read<RoleDashboardController>();
    final labResults = controller.labResults;

    final matches = <_PatientCandidate>[];
    final seen = <String>{};

    // Search in local lab records first
    for (final r in labResults) {
      final hit =
          r.patientName.toLowerCase().contains(q.toLowerCase()) ||
          r.mobileNumber.toLowerCase().contains(q.toLowerCase());
      if (!hit) continue;

      final key = '${r.patientName}|${r.mobileNumber}'.toLowerCase();
      if (seen.add(key)) {
        matches.add(
          _PatientCandidate(
            name: r.patientName,
            phone: r.mobileNumber,
            patientType: r.patientType,
            source: 'Lab records',
          ),
        );
      }
    }

    // Then search in user database
    try {
      final found = await _client.doctor.getPatientByPhone(q);

      final name = found['name'];
      final phone = found['phone'];
      final role = found['role'];

      if ((name is String && name.trim().isNotEmpty) &&
          (phone is String && phone.trim().isNotEmpty)) {
        final key = '$name|$phone'.toLowerCase();
        if (seen.add(key)) {
          matches.add(
            _PatientCandidate(
              name: name,
              phone: phone,
              patientType: role is String ? role : '',
              source: 'User database',
            ),
          );
        }
      }
    } catch (e) {
      // Keep local matches only if backend call fails
      debugPrint('Patient search error: $e');
    }

    if (!mounted) return;
    setState(() {
      _patientMatches
        ..clear()
        ..addAll(matches);
      _lookupLoading = false;
    });
  }

  Future<void> _createTestEntries(RoleDashboardController controller) async {
    final patientName = _patientNameCtrl.text.trim();
    final mobile = _mobileCtrl.text.trim();

    if (_selectedTestIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one test.')),
      );
      return;
    }

    if (patientName.isEmpty || mobile.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter patient name and phone.')),
      );
      return;
    }

    setState(() => _creating = true);
    var successCount = 0;

    try {
      for (final testId in _selectedTestIds) {
        final ok = await _client.lab.createTestResult(
          testId: testId,
          patientName: patientName,
          mobileNumber: mobile,
          patientType: _patientType,
        );
        if (ok) successCount++;
      }

      if (!mounted) return;

      if (successCount == _selectedTestIds.length) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$successCount test ID(s) created successfully.'),
          ),
        );
        setState(() {
          _selectedTestIds.clear();
          _patientNameCtrl.clear();
          _mobileCtrl.text = '+8801';
          _customFeeCtrl.clear();
          _lookupQuery = '';
          _patientMatches.clear();
        });
        await controller.loadLab();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$successCount/${_selectedTestIds.length} test ID(s) created. Please retry failed ones.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _creating = false);
      }
    }
  }

  Future<void> _loadAvailableTestsFallback() async {
    setState(() => _testsLoading = true);
    try {
      final tests = await _client.lab.getAllLabTests();
      if (!mounted) return;
      setState(() {
        _fallbackTests = tests;
      });
    } catch (_) {
      // Keep existing state; UI already provides manual refresh and message.
    } finally {
      if (mounted) {
        setState(() => _testsLoading = false);
      }
    }
  }

  Widget _buildPendingTitle() {
    return Text(
      'Pending Test Queue (Last 24 Hours)',
      style: Theme.of(
        context,
      ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
    );
  }

  Widget _buildPendingTable(
    List<TestResult> pending,
    Map<int, String> testNameById,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: const Row(
              children: [
                Expanded(flex: 30, child: Text('Patient Details')),
                Expanded(flex: 16, child: Text('Test(s)')),
                Expanded(
                  flex: 13,
                  child: Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Text('Created At'),
                  ),
                ),
                Expanded(
                  flex: 12,
                  child: Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Text('Patient Type'),
                  ),
                ),
                Expanded(flex: 11, child: Text('Actions')),
              ],
            ),
          ),
          SizedBox(
            height: 360,
            child: ListView.builder(
              itemCount: pending.length,
              itemBuilder: (context, index) {
                final item = pending[index];
                return _PendingQueueRow(
                  item: item,
                  index: index,
                  testName: testNameById[item.testId] ?? 'Test ${item.testId}',
                  status: _statusForIndex(index),
                  onUploadFile: () => _openUploadReportDialog(
                    item,
                    context.read<RoleDashboardController>(),
                  ),
                  onPrintReceipt: () => _openReceiptPreviewForResult(
                    item,
                    testNameById,
                    _fallbackTests,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedHeader(int completedCount, double revenue) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Completed Tests (Today)',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text('$completedCount Tests Completed Today'),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 280,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Today\'s Revenue Summary',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [const Text('Tests'), Text('$completedCount')],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Custom Fees'),
                      Text('Tk ${revenue.toStringAsFixed(0)}'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchSortBar() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: (value) => setState(() => _search = value),
                decoration: const InputDecoration(
                  hintText: 'Search...',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Text('Sort by:'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _sortBy,
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All')),
                    DropdownMenuItem(value: 'Recent', child: Text('Recent')),
                    DropdownMenuItem(value: 'Name', child: Text('Name')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _sortBy = value);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedTable(
    List<TestResult> completed,
    Map<int, String> testNameById,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
          columns: const [
            DataColumn(label: Text('Patient Details')),
            DataColumn(label: Text('Test(s)')),
            DataColumn(label: Text('Completed At')),
            DataColumn(label: Text('Actions')),
          ],
          rows: completed.map((result) {
            final completedAt = result.submittedAt ?? result.createdAt;
            final testName =
                testNameById[result.testId] ?? 'Test ${result.testId}';
            return DataRow(
              cells: [
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        result.patientName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(result.mobileNumber),
                    ],
                  ),
                ),
                DataCell(Text(testName)),
                DataCell(
                  Text(
                    completedAt == null
                        ? '-'
                        : DateFormat(
                            'HH:mm:ss\ndd/MM/yyyy',
                          ).format(completedAt),
                  ),
                ),
                DataCell(
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _openReceiptPreviewForResult(
                          result,
                          testNameById,
                          _fallbackTests,
                        ),
                        icon: const Icon(Icons.print_outlined, size: 16),
                        label: const Text('Reprint Receipt'),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _fieldBlock(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  _QueueStatus _statusForIndex(int index) {
    const values = [
      _QueueStatus.waiting,
      _QueueStatus.processing,
      _QueueStatus.ready,
      _QueueStatus.waiting,
      _QueueStatus.processing,
    ];
    return values[index % values.length];
  }

  double _feeForResult(TestResult result, List<LabTests> tests) {
    final match = tests.where((t) => t.id == result.testId).toList();
    if (match.isEmpty) return 0;
    final test = match.first;
    final patientType = result.patientType.toUpperCase();

    if (patientType.contains('STUDENT')) return test.studentFee;
    if (patientType.contains('STAFF')) return test.teacherFee;
    return test.outsideFee;
  }

  double _feeForType(LabTests test, String patientType) {
    final t = patientType.toUpperCase();
    if (t.contains('STUDENT')) return test.studentFee;
    if (t.contains('STAFF') || t.contains('TEACHER')) return test.teacherFee;
    return test.outsideFee;
  }

  String _buildBarcodePayload({
    required String patientName,
    required String phone,
    required String serial,
  }) {
    final normalizedName = patientName
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9 ]'), '')
        .replaceAll(RegExp(r'\s+'), ' ');
    final compactName = (normalizedName.isEmpty ? 'UNKNOWN' : normalizedName)
        .substring(
          0,
          (normalizedName.isEmpty ? 'UNKNOWN' : normalizedName).length > 18
              ? 18
              : (normalizedName.isEmpty ? 'UNKNOWN' : normalizedName).length,
        );
    final normalizedPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final compactPhone = normalizedPhone.length > 13
        ? normalizedPhone.substring(normalizedPhone.length - 13)
        : normalizedPhone;
    final compactSerial = serial.toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9-]'),
      '',
    );

    // Keep payload short for 1D barcode scan reliability on phones.
    return 'SN=$compactSerial;PH=$compactPhone;NM=$compactName';
  }

  void _openReceiptPreviewFromForm(List<LabTests> tests) {
    final patientName = _patientNameCtrl.text.trim();
    final mobile = _mobileCtrl.text.trim();

    if (patientName.isEmpty || mobile.isEmpty || _selectedTestIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select test(s) and enter patient name/phone first.'),
        ),
      );
      return;
    }

    final selectedTests = tests
        .where((t) => t.id != null && _selectedTestIds.contains(t.id))
        .toList();

    final lines = <_ReceiptLine>[];
    for (final test in selectedTests) {
      final code =
          ((test.testName.isNotEmpty ? test.testName : 'T')
                  .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
                  .toUpperCase())
              .padRight(3, 'X')
              .substring(0, 3);
      lines.add(
        _ReceiptLine(
          code: code,
          name: test.testName,
          tat: '1 Hr',
          type: _patientType,
          amount: _feeForType(test, _patientType),
        ),
      );
    }

    if (lines.isEmpty) return;

    final now = DateTime.now();
    final serial =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';
    final barcodeText = _buildBarcodePayload(
      patientName: patientName,
      phone: mobile,
      serial: serial,
    );

    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: _ReceiptPreview(
          patientName: patientName,
          mobile: mobile,
          createdAt: now,
          invoiceNo:
              '#NSTU-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecond.toString().padLeft(3, '0')}',
          lines: lines,
          barcodeText: barcodeText,
        ),
      ),
    );
  }

  void _openReceiptPreviewForResult(
    TestResult result,
    Map<int, String> testNameById,
    List<LabTests> tests,
  ) {
    final testName = testNameById[result.testId] ?? 'Test ${result.testId}';
    final code =
        (testName.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase())
            .padRight(3, 'X')
            .substring(0, 3);

    final amount = _feeForResult(result, tests);
    final created = result.createdAt ?? DateTime.now();
    final idPart = (result.resultId ?? created.millisecondsSinceEpoch)
        .toString();
    final barcodeText = _buildBarcodePayload(
      patientName: result.patientName,
      phone: result.mobileNumber,
      serial: idPart,
    );

    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: _ReceiptPreview(
          patientName: result.patientName.trim().isEmpty
              ? 'Unknown Patient'
              : result.patientName,
          mobile: result.mobileNumber,
          createdAt: created,
          invoiceNo: '#NSTU-$idPart',
          lines: [
            _ReceiptLine(
              code: code,
              name: testName,
              tat: '1 Hr',
              type: result.patientType.isEmpty ? 'STUDENT' : result.patientType,
              amount: amount,
            ),
          ],
          barcodeText: barcodeText,
        ),
      ),
    );
  }

  Future<void> _openUploadReportDialog(
    TestResult item,
    RoleDashboardController controller,
  ) async {
    final resultId = item.resultId;
    if (resultId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid result ID for this row.')),
      );
      return;
    }

    PlatformFile? selectedFile;
    Uint8List? selectedBytes;
    bool uploading = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Send Uploaded Test Report'),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Patient: ${item.patientName}'),
                    Text('Mobile: ${item.mobileNumber}'),
                    const SizedBox(height: 10),
                    FilledButton.tonalIcon(
                      onPressed: uploading
                          ? null
                          : () async {
                              final picked = await FilePicker.platform.pickFiles(
                                type: FileType.custom,
                                allowedExtensions: const [
                                  'pdf',
                                  'png',
                                  'jpg',
                                  'jpeg',
                                ],
                                withData: true,
                              );
                              if (picked == null || picked.files.isEmpty) {
                                return;
                              }

                              final file = picked.files.first;
                              final bytes = file.bytes;
                              if (bytes == null || bytes.isEmpty) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Could not read the selected file. Please try another file.',
                                    ),
                                  ),
                                );
                                return;
                              }

                              setDialogState(() {
                                selectedFile = file;
                                selectedBytes = bytes;
                              });
                            },
                      icon: const Icon(Icons.upload_file_outlined),
                      label: const Text('Choose File'),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        selectedFile == null
                            ? 'No file selected yet.'
                            : 'Selected: ${selectedFile!.name}',
                        style: const TextStyle(color: Color(0xFF334155)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: uploading
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: uploading
                      ? null
                      : () async {
                          if (selectedBytes == null || selectedFile == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please choose a file first.',
                                ),
                              ),
                            );
                            return;
                          }

                          setDialogState(() => uploading = true);
                          try {
                            final uploadedUrl = await CloudinaryUpload.uploadAuto(
                              bytes: selectedBytes!,
                              folder: 'nstu/lab-reports',
                              fileName: selectedFile!.name,
                            );
                            if (uploadedUrl == null || uploadedUrl.isEmpty) {
                              if (!mounted) return;
                              setDialogState(() => uploading = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'File upload failed. Please retry with a smaller or supported file.',
                                  ),
                                ),
                              );
                              return;
                            }

                            final ok = await _client.lab.submitResultWithUrl(
                              resultId: resultId,
                              attachmentUrl: uploadedUrl,
                            );

                            if (!mounted) return;
                            if (ok) {
                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext);
                              }
                              await controller.loadLab();
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Test report uploaded and submitted successfully.',
                                  ),
                                ),
                              );
                            } else {
                              setDialogState(() => uploading = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Could not submit report after upload. Please retry.',
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (!mounted) return;
                            setDialogState(() => uploading = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to upload report: $e'),
                              ),
                            );
                          }
                        },
                  icon: uploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload_outlined),
                  label: Text(uploading ? 'Uploading...' : 'Upload & Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

enum _QueueStatus { waiting, processing, ready }

class _PendingQueueRow extends StatelessWidget {
  const _PendingQueueRow({
    required this.item,
    required this.index,
    required this.testName,
    required this.status,
    required this.onUploadFile,
    required this.onPrintReceipt,
  });

  final TestResult item;
  final int index;
  final String testName;
  final _QueueStatus status;
  final VoidCallback onUploadFile;
  final VoidCallback onPrintReceipt;

  @override
  Widget build(BuildContext context) {
    final rowColor = index.isEven ? const Color(0xFFF8FAFC) : Colors.white;

    return Container(
      color: rowColor,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 30,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: const Color(0xFFE2E8F0),
                  child: Text('${index + 1}'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.patientName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(item.mobileNumber),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 16,
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(testName),
                ),
                _StatusTag(status: status),
              ],
            ),
          ),
          Expanded(
            flex: 13,
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                item.createdAt == null
                    ? '-'
                    : DateFormat(
                        'HH:mm:ss\ndd/MM/yyyy',
                      ).format(item.createdAt!),
              ),
            ),
          ),
          Expanded(
            flex: 12,
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(item.patientType),
            ),
          ),
          Expanded(
            flex: 11,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: const Color(0xFF0D9488),
                  ),
                  onPressed: onUploadFile,
                  child: const Text('Upload File'),
                ),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: onPrintReceipt,
                  icon: const Icon(Icons.print_outlined, size: 14),
                  label: const Text('Print Receipt'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.status});

  final _QueueStatus status;

  @override
  Widget build(BuildContext context) {
    String label;
    Color bg;
    Color fg;

    switch (status) {
      case _QueueStatus.waiting:
        label = 'WAITING';
        bg = const Color(0xFFE2E8F0);
        fg = const Color(0xFF334155);
        break;
      case _QueueStatus.processing:
        label = 'PROCESSING';
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF92400E);
        break;
      case _QueueStatus.ready:
        label = 'READY';
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF166534);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

class _PatientCandidate {
  const _PatientCandidate({
    required this.name,
    required this.phone,
    required this.source,
    this.patientType,
  });

  final String name;
  final String phone;
  final String source;
  final String? patientType;
}

class _ReceiptLine {
  const _ReceiptLine({
    required this.code,
    required this.name,
    required this.tat,
    required this.type,
    required this.amount,
  });

  final String code;
  final String name;
  final String tat;
  final String type;
  final double amount;
}

class _ReceiptPreview extends StatelessWidget {
  const _ReceiptPreview({
    required this.patientName,
    required this.mobile,
    required this.createdAt,
    required this.invoiceNo,
    required this.lines,
    required this.barcodeText,
  });

  final String patientName;
  final String mobile;
  final DateTime createdAt;
  final String invoiceNo;
  final List<_ReceiptLine> lines;
  final String barcodeText;

  String _buildPrintableHtml() {
    String? barcodeSvg;
    try {
      barcodeSvg = Barcode.code128().toSvg(
        barcodeText,
        width: 470,
        height: 110,
        drawText: false,
      );
    } catch (_) {
      barcodeSvg = null;
    }

    return buildNstuLabReceiptHtml(
      title: 'Lab Receipt',
      patientName: patientName,
      mobile: mobile,
      invoiceNo: invoiceNo,
      dateTime: DateFormat('dd/MM/yyyy HH:mm').format(createdAt),
      lines: lines
          .map(
            (line) => ReceiptLineItem(
              code: line.code,
              name: line.name,
              type: line.type,
              amount: line.amount,
              extra: line.tat,
            ),
          )
          .toList(),
      barcodeSvg: barcodeSvg,
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = lines.fold<double>(0, (sum, line) => sum + line.amount);

    return SizedBox(
      width: 560,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text(
                  'Print Receipt Preview',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
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
            const Text(
              'PATIENT DETAILS (BARCODE)',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            BarcodeWidget(
              barcode: Barcode.code128(),
              data: barcodeText,
              width: 470,
              height: 110,
              drawText: false,
            ),
            const SizedBox(height: 12),
            const Text(
              'NSTU',
              style: TextStyle(fontSize: 46, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: Text('Patient: $patientName\nMobile: $mobile')),
                Expanded(
                  child: Text(
                    'Date: ${DateFormat('dd/MM/yyyy').format(createdAt)}\n'
                    'Created At: ${DateFormat('HH:mm:ss').format(createdAt)}\n'
                    'Invoice: $invoiceNo',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Table(
              border: TableBorder.all(color: const Color(0xFFCBD5E1)),
              columnWidths: const {
                0: FlexColumnWidth(1.2),
                1: FlexColumnWidth(3.6),
                2: FlexColumnWidth(1.1),
                3: FlexColumnWidth(1.3),
                4: FlexColumnWidth(1.7),
              },
              children: [
                const TableRow(
                  decoration: BoxDecoration(color: Color(0xFFF1F5F9)),
                  children: [
                    Padding(
                      padding: EdgeInsets.all(6),
                      child: Text(
                        'Code',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(6),
                      child: Text(
                        'Test Name',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(6),
                      child: Text(
                        'TAT',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(6),
                      child: Text(
                        'Type',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(6),
                      child: Text(
                        'Amount (৳)',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                ...lines.map(
                  (line) => TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(line.code),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(line.name),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(line.tat),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(line.type),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(line.amount.toStringAsFixed(2)),
                      ),
                    ],
                  ),
                ),
                TableRow(
                  decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
                  children: [
                    const SizedBox.shrink(),
                    const Padding(
                      padding: EdgeInsets.all(6),
                      child: Text(
                        'Total Due',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox.shrink(),
                    const SizedBox.shrink(),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        total.toStringAsFixed(2),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ],
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
                label: const Text('PRINT / SAVE PDF'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
