import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/role_dashboard_controller.dart';
import '../../widgets/common/dashboard_shell.dart';

class DoctorRecordsPage extends StatefulWidget {
  const DoctorRecordsPage({super.key});

  @override
  State<DoctorRecordsPage> createState() => _DoctorRecordsPageState();
}

class _DoctorRecordsPageState extends State<DoctorRecordsPage> {
  final _searchController = TextEditingController();
  List<dynamic> _results = const [];
  Map<String, String?>? _dbProfileOnlyMatch;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_searchPatients);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchPatients() async {
    if (!mounted) return;
    setState(() {
      _isSearching = true;
      _dbProfileOnlyMatch = null;
    });

    final c = context.read<RoleDashboardController>();
    final query = _searchController.text.trim();
    final rows = await c.searchDoctorPatients(query: query, limit: 50);

    Map<String, String?>? dbFallback;
    if (rows.isEmpty && query.isNotEmpty) {
      final profile = await c.lookupDoctorPatient(query);
      final hasId = (profile['id'] ?? '').trim().isNotEmpty;
      final hasName = (profile['name'] ?? '').trim().isNotEmpty;
      if (hasId || hasName) {
        dbFallback = profile;
      }
    }

    if (!mounted) return;
    setState(() {
      _results = rows;
      _dbProfileOnlyMatch = dbFallback;
      _isSearching = false;
    });
  }

  void _openPrescriptionCreator({
    String? patientId,
    int? prescriptionId,
    String? fullName,
    String? phone,
    String? age,
    String? gender,
    String? bloodGroup,
    bool isNewRecord = false,
  }) {
    final uri = Uri(
      path: '/doctor/prescriptions/create',
      queryParameters: {
        if (patientId != null && patientId.isNotEmpty) 'patientId': patientId,
        if (prescriptionId != null) 'prescriptionId': prescriptionId.toString(),
        if (fullName != null && fullName.isNotEmpty) 'name': fullName,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (age != null && age.isNotEmpty) 'age': age,
        if (gender != null && gender.isNotEmpty) 'gender': gender,
        if (bloodGroup != null && bloodGroup.isNotEmpty)
          'bloodGroup': bloodGroup,
        'new': isNewRecord ? '1' : '0',
      },
    );
    context.go(uri.toString());
  }

  Future<void> _showCreateNewPatientDialog() async {
    String name = '';
    String phone = _searchController.text.trim().replaceAll(
      RegExp(r'[^0-9+]'),
      '',
    );
    String age = '';
    String gender = 'Male';
    String bloodGroup = 'O+';

    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create New Patient Record'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      onChanged: (value) => name = value,
                      decoration: const InputDecoration(labelText: 'Full Name'),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: phone,
                      onChanged: (value) => phone = value,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: age,
                      onChanged: (value) => age = value,
                      decoration: const InputDecoration(labelText: 'Age'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: gender,
                      decoration: const InputDecoration(labelText: 'Gender'),
                      items: const [
                        DropdownMenuItem(value: 'Male', child: Text('Male')),
                        DropdownMenuItem(
                          value: 'Female',
                          child: Text('Female'),
                        ),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (value) {
                        setDialogState(() => gender = value ?? 'Male');
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: bloodGroup,
                      decoration: const InputDecoration(
                        labelText: 'Blood Group',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'A+', child: Text('A+')),
                        DropdownMenuItem(value: 'A-', child: Text('A-')),
                        DropdownMenuItem(value: 'B+', child: Text('B+')),
                        DropdownMenuItem(value: 'B-', child: Text('B-')),
                        DropdownMenuItem(value: 'AB+', child: Text('AB+')),
                        DropdownMenuItem(value: 'AB-', child: Text('AB-')),
                        DropdownMenuItem(value: 'O+', child: Text('O+')),
                        DropdownMenuItem(value: 'O-', child: Text('O-')),
                      ],
                      onChanged: (value) {
                        setDialogState(() => bloodGroup = value ?? 'O+');
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final trimmedName = name.trim();
                final trimmedPhone = phone.trim();
                if (trimmedName.isEmpty || trimmedPhone.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please provide at least name and phone.'),
                    ),
                  );
                  return;
                }
                Navigator.of(context).pop(true);
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    if (submitted == true && mounted) {
      _openPrescriptionCreator(
        fullName: name.trim(),
        phone: phone.trim(),
        age: age.trim(),
        gender: gender,
        bloodGroup: bloodGroup,
        isNewRecord: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<RoleDashboardController>();
    final hasRows = _results.isNotEmpty;
    final fallback = _dbProfileOnlyMatch;

    return DashboardShell(
      child: ListView(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Search Results',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _searchController.text.trim().isEmpty
                          ? 'Search by patient name or phone to see records.'
                          : 'Showing DB search matches for "${_searchController.text.trim()}"',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _showCreateNewPatientDialog,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('New Patient'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: 'Search by name or phone...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onSubmitted: (_) => _searchPatients(),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _isSearching ? null : _searchPatients,
                icon: _isSearching
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search_rounded),
                label: const Text('Search'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                  ),
                  child: Row(
                    children: const [
                      Expanded(flex: 2, child: Text('PATIENT ID')),
                      Expanded(flex: 3, child: Text('FULL NAME')),
                      Expanded(flex: 2, child: Text('GENDER')),
                      Expanded(flex: 2, child: Text('LAST VISIT')),
                      Expanded(flex: 2, child: Text('ACTION')),
                    ],
                  ),
                ),
                if (_isSearching)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  )
                else if (hasRows)
                  ..._results.map((row) {
                    final gender = (row.gender as String?)?.trim();
                    final date = row.prescriptionDate as DateTime?;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Color(0xFFF1F5F9)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              '#PT-${row.prescriptionId}',
                              style: const TextStyle(
                                color: Color(0xFFEA580C),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              row.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDBEAFE),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  (gender == null || gender.isEmpty)
                                      ? '-'
                                      : gender,
                                  style: const TextStyle(
                                    color: Color(0xFF1D4ED8),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              date == null
                                  ? '-'
                                  : DateFormat('MMM dd, yyyy').format(date),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: () {
                                  _openPrescriptionCreator(
                                    patientId: row.prescriptionId.toString(),
                                    prescriptionId: row.prescriptionId,
                                    fullName: row.name,
                                    phone: row.mobileNumber,
                                    age: row.age?.toString(),
                                    gender: row.gender,
                                    bloodGroup: row.bloodGroup,
                                    isNewRecord: false,
                                  );
                                },
                                child: const Text('Open Prescription →'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  })
                else
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          'No patient record found in prescriptions.',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        if (fallback != null)
                          Text(
                            'Patient exists in DB: ${fallback['name'] ?? '-'} (${fallback['phone'] ?? 'No phone'})',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          alignment: WrapAlignment.center,
                          children: [
                            FilledButton.icon(
                              onPressed: fallback == null
                                  ? _showCreateNewPatientDialog
                                  : () {
                                      _openPrescriptionCreator(
                                        patientId: fallback['id'],
                                        fullName: fallback['name'],
                                        phone: fallback['phone'],
                                        age: fallback['age'],
                                        gender: fallback['gender'],
                                        bloodGroup: fallback['bloodGroup'],
                                        isNewRecord: false,
                                      );
                                    },
                              icon: const Icon(Icons.edit_note_rounded),
                              label: Text(
                                fallback == null
                                    ? 'Create New Record + Prescription'
                                    : 'Create First Prescription',
                              ),
                            ),
                            OutlinedButton(
                              onPressed: _searchPatients,
                              child: const Text('Refresh Search'),
                            ),
                          ],
                        ),
                        if (c.error != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            c.error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(
                    Icons.help_outline_rounded,
                    color: Color(0xFFEA580C),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Didn\'t find the patient? Search with full phone or create a new patient record and continue with prescription.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: _showCreateNewPatientDialog,
                    child: const Text('Advanced Search'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
