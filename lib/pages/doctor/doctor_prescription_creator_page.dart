import 'package:backend_client/backend_client.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/role_dashboard_controller.dart';
import '../../utils/prescription_pdf_service.dart';
import '../../utils/receipt_print_service.dart';
import '../../widgets/common/dashboard_shell.dart';

class DoctorPrescriptionCreatorPage extends StatefulWidget {
  const DoctorPrescriptionCreatorPage({
    super.key,
    this.patientId,
    this.prescriptionId,
    this.patientName,
    this.phone,
    this.age,
    this.gender,
    this.isNewRecord = false,
  });

  final String? patientId;
  final int? prescriptionId;
  final String? patientName;
  final String? phone;
  final String? age;
  final String? gender;
  final bool isNewRecord;

  @override
  State<DoctorPrescriptionCreatorPage> createState() =>
      _DoctorPrescriptionCreatorPageState();
}

class _DoctorPrescriptionCreatorPageState
    extends State<DoctorPrescriptionCreatorPage> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _ageCtrl;
  late final TextEditingController _diagnosisCtrl;
  late final TextEditingController _testCtrl;
  late final TextEditingController _adviceCtrl;
  late final TextEditingController _bpCtrl;
  late final TextEditingController _temperatureCtrl;
  late final TextEditingController _nextVisitCtrl;

  final List<_MedicationRowData> _medications = [_MedicationRowData()];

  bool _isSaving = false;
  bool _isLoadingDetails = false;
  String _gender = 'Male';
  String _bloodGroup = '-';

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.patientName ?? '');
    _phoneCtrl = TextEditingController(text: widget.phone ?? '');
    _ageCtrl = TextEditingController(text: widget.age ?? '');
    _diagnosisCtrl = TextEditingController();
    _testCtrl = TextEditingController();
    _adviceCtrl = TextEditingController();
    _bpCtrl = TextEditingController(text: '120/80');
    _temperatureCtrl = TextEditingController(text: '98.6');
    _nextVisitCtrl = TextEditingController();

    final normalizedGender = (widget.gender ?? '').trim().toLowerCase();
    if (normalizedGender == 'female') {
      _gender = 'Female';
    } else if (normalizedGender == 'other') {
      _gender = 'Other';
    }

    final parsedBloodGroup = (Uri.base.queryParameters['bloodGroup'] ?? '')
        .trim();
    if (parsedBloodGroup.isNotEmpty) {
      _bloodGroup = parsedBloodGroup;
    }

    if (widget.prescriptionId != null) {
      _loadExistingPrescription(widget.prescriptionId!);
    }
  }

  Future<void> _loadExistingPrescription(int prescriptionId) async {
    setState(() => _isLoadingDetails = true);
    final c = context.read<RoleDashboardController>();
    final details = await c.loadPrescriptionDetails(prescriptionId);
    if (!mounted) return;
    if (details == null) {
      setState(() => _isLoadingDetails = false);
      return;
    }

    _diagnosisCtrl.text = details.cc ?? '';
    _testCtrl.text = details.test ?? '';
    _adviceCtrl.text = details.advice ?? '';
    _bpCtrl.text = (details.bp ?? '').trim().isEmpty ? '120/80' : details.bp!;
    _temperatureCtrl.text = (details.temperature ?? '').trim().isEmpty
        ? '98.6'
        : details.temperature!;

    if (details.items.isNotEmpty) {
      _medications.clear();
      for (final item in details.items) {
        final row = _MedicationRowData();
        row.medicineCtrl.text = item.medicineName;
        row.durationCtrl.text = item.duration != null
            ? item.duration.toString()
            : '';
        final dosage = (item.dosageTimes ?? '').toLowerCase();
        row.times['Morning'] = dosage.contains('morning');
        row.times['Afternoon'] = dosage.contains('afternoon');
        row.times['Night'] = dosage.contains('night');
        final meal = (item.mealTiming ?? '').toLowerCase();
        if (meal.contains('before')) {
          row.mealTiming = 'before';
        } else {
          row.mealTiming = 'after';
        }
        // Parse time note from meal timing (e.g. "30 min, Before meal")
        if (item.mealTiming != null && item.mealTiming!.contains(',')) {
          row.mealTimeCtrl.text = item.mealTiming!.split(',').first.trim();
        }
        _medications.add(row);
      }
    }

    setState(() => _isLoadingDetails = false);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _ageCtrl.dispose();
    _diagnosisCtrl.dispose();
    _testCtrl.dispose();
    _adviceCtrl.dispose();
    _bpCtrl.dispose();
    _temperatureCtrl.dispose();
    _nextVisitCtrl.dispose();
    for (final medication in _medications) {
      medication.dispose();
    }
    super.dispose();
  }

  Future<void> _savePrescription({bool printAfterSave = true}) async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient name and phone are required.')),
      );
      return;
    }

    final preparedItems = _medications
        .where((m) => m.medicineCtrl.text.trim().isNotEmpty)
        .map((m) {
          final durationText = m.durationCtrl.text.trim();
          final durationDigits = RegExp(
            r'\d+',
          ).firstMatch(durationText)?.group(0);
          return PrescribedItem(
            prescriptionId: 0,
            medicineName: m.medicineCtrl.text.trim(),
            dosageTimes: _dosageSummary(m).trim().isEmpty
                ? null
                : _dosageSummary(m),
            mealTiming: _formattedMealInstruction(m),
            duration: int.tryParse(durationDigits ?? ''),
          );
        })
        .toList();

    if (preparedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one medication.')),
      );
      return;
    }

    final prescription = Prescription(
      doctorId: 0,
      name: name,
      mobileNumber: phone,
      age: int.tryParse(_ageCtrl.text.trim()),
      gender: _gender,
      prescriptionDate: DateTime.now(),
      cc: _diagnosisCtrl.text.trim().isEmpty
          ? null
          : _diagnosisCtrl.text.trim(),
      oe: _buildOeForSave(),
      bp: _bpCtrl.text.trim().isEmpty ? null : _bpCtrl.text.trim(),
      temperature: _temperatureCtrl.text.trim().isEmpty
          ? null
          : _temperatureCtrl.text.trim(),
      advice: _adviceCtrl.text.trim().isEmpty ? null : _adviceCtrl.text.trim(),
      test: _testCtrl.text.trim().isEmpty ? null : _testCtrl.text.trim(),
      nextVisit: _nextVisitCtrl.text.trim().isEmpty
          ? null
          : '${_nextVisitCtrl.text.trim()} days',
      isOutside: widget.isNewRecord ? true : null,
    );

    setState(() => _isSaving = true);
    final c = context.read<RoleDashboardController>();
    final resultId = await c.saveDoctorPrescription(
      prescription: prescription,
      items: preparedItems,
      patientPhone: phone,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (resultId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            c.error ?? 'Failed to save prescription. Please retry.',
          ),
        ),
      );
      return;
    }

    if (printAfterSave) {
      _printPrescription();
      if (!mounted) return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          printAfterSave
              ? 'Prescription #$resultId saved and print preview opened.'
              : 'Prescription #$resultId saved successfully.',
        ),
      ),
    );

    if (printAfterSave) {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
    }

    context.go('/doctor/patients');
  }

  String _valueOrDash(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? '-' : trimmed;
  }

  String? _buildOeForSave() {
    final bp = _bpCtrl.text.trim();
    final temp = _temperatureCtrl.text.trim();
    final parts = <String>[];

    if (bp.isNotEmpty) {
      parts.add('BP: $bp');
    }
    if (temp.isNotEmpty) {
      parts.add('Temp: $temp °F');
    }

    if (parts.isEmpty) return null;
    return parts.join(', ');
  }

  String _dosageSummary(_MedicationRowData row) {
    if (row.isFourTimes) return '4 times';
    return row.times.entries.where((e) => e.value).map((e) => e.key).join(', ');
  }

  String _mealLabel(_MedicationRowData row) {
    return row.mealTiming == 'before' ? 'Before meal' : 'After meal';
  }

  String _formattedMealInstruction(_MedicationRowData row) {
    final mealLabel = _mealLabel(row);
    final timeNote = row.mealTimeCtrl.text.trim();
    if (timeNote.isEmpty) return mealLabel;
    return '$timeNote, $mealLabel';
  }

  String _buildPrescriptionHtml() {
    final dateLabel = DateFormat('d/M/yyyy').format(DateTime.now());
    final patientId = (widget.patientId != null && widget.patientId!.isNotEmpty)
        ? '#${widget.patientId}'
        : 'NEW';

    return buildNstuPrescriptionHtml(
      patientName: _valueOrDash(_nameCtrl.text),
      mobile: _valueOrDash(_phoneCtrl.text),
      age: _ageCtrl.text.trim().isEmpty ? '-' : '${_ageCtrl.text.trim()} years',
      gender: _valueOrDash(_gender),
      bloodGroup: _valueOrDash(_bloodGroup),
      patientId: patientId,
      date: dateLabel,
      bp: _valueOrDash(_bpCtrl.text),
      temperature: _temperatureCtrl.text.trim().isEmpty
          ? '-'
          : '${_temperatureCtrl.text.trim()} °F',
      diagnosis: _valueOrDash(_diagnosisCtrl.text),
      suggestedTests: _valueOrDash(_testCtrl.text),
      advice: _valueOrDash(_adviceCtrl.text),
      nextVisit: _nextVisitCtrl.text.trim().isEmpty
          ? 'As advised'
          : '${_nextVisitCtrl.text.trim()} days',
      medicines: _medications
          .where((m) => m.medicineCtrl.text.trim().isNotEmpty)
          .map(
            (m) => PrescriptionMedicineLine(
              medicine: _valueOrDash(m.medicineCtrl.text),
              dosage: _valueOrDash(_dosageSummary(m)),
              frequency: _valueOrDash(_mealLabel(m)),
              duration: _valueOrDash(m.durationCtrl.text),
              notes: m.mealTimeCtrl.text.trim(),
            ),
          )
          .toList(),
    );
  }

  List<PrescriptionMedicineLine> _buildPrescriptionMedicineLines() {
    return _medications
        .where((m) => m.medicineCtrl.text.trim().isNotEmpty)
        .map(
          (m) => PrescriptionMedicineLine(
            medicine: _valueOrDash(m.medicineCtrl.text),
            dosage: _valueOrDash(_dosageSummary(m)),
            frequency: _valueOrDash(_mealLabel(m)),
            duration: _valueOrDash(m.durationCtrl.text),
            notes: m.mealTimeCtrl.text.trim(),
          ),
        )
        .toList();
  }

  Future<void> _downloadPrescriptionPdf({
    bool showSuccessSnackBar = true,
  }) async {
    try {
      final fileDate = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final patientId =
          (widget.patientId != null && widget.patientId!.isNotEmpty)
          ? '#${widget.patientId}'
          : 'NEW';
      final pdfBytes = await buildNstuPrescriptionPdf(
        patientName: _valueOrDash(_nameCtrl.text),
        mobile: _valueOrDash(_phoneCtrl.text),
        age: _ageCtrl.text.trim().isEmpty
            ? '-'
            : '${_ageCtrl.text.trim()} years',
        gender: _valueOrDash(_gender),
        bloodGroup: _valueOrDash(_bloodGroup),
        patientId: patientId,
        date: DateFormat('d/M/yyyy').format(DateTime.now()),
        bp: _valueOrDash(_bpCtrl.text),
        temperature: _temperatureCtrl.text.trim().isEmpty
            ? '-'
            : '${_temperatureCtrl.text.trim()} °F',
        diagnosis: _valueOrDash(_diagnosisCtrl.text),
        suggestedTests: _valueOrDash(_testCtrl.text),
        advice: _valueOrDash(_adviceCtrl.text),
        nextVisit: _nextVisitCtrl.text.trim().isEmpty
            ? 'As advised'
            : '${_nextVisitCtrl.text.trim()} days',
        medicines: _buildPrescriptionMedicineLines(),
      );

      downloadFileBytes(
        pdfBytes,
        'nstu_prescription_$fileDate.pdf',
        'application/pdf',
      );

      if (!mounted || !showSuccessSnackBar) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prescription PDF downloaded.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to download PDF: $e')));
    }
  }

  void _printPrescription() {
    printReceiptHtml(_buildPrescriptionHtml());
  }

  Future<void> _downloadPrescription() async {
    await _downloadPrescriptionPdf();
  }

  @override
  Widget build(BuildContext context) {
    final patientLabel =
        (widget.patientId != null && widget.patientId!.isNotEmpty)
        ? '#${widget.patientId}'
        : 'NEW';
    final todayLabel = DateFormat('dd MMMM yyyy').format(DateTime.now());

    return DashboardShell(
      child: _isLoadingDetails
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // ── Breadcrumb ──────────────────────────────────────────────
                Row(
                  children: [
                    const Icon(
                      Icons.people_alt_outlined,
                      size: 14,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Patients',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        Icons.chevron_right,
                        size: 14,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const Text(
                      'Prescription Creator',
                      style: TextStyle(
                        color: Color(0xFF2563EB),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 84,
                          height: 84,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.asset(
                              'assets/images/nstu_logo.jpg',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'মেডিকেল সেন্টার',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: 'Kalpurush',
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'নোয়াখালী বিজ্ঞান ও প্রযুক্তি বিশ্ববিদ্যালয়',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: 'Kalpurush',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF334155),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                width: 280,
                                height: 1.5,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0x142563EB),
                                      Color(0xFF2563EB),
                                      Color(0x142563EB),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Noakhali Science and Technology University',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 10,
                                runSpacing: 6,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Text(
                                      'Doctor Prescription',
                                      style: TextStyle(
                                        color: Color(0xFF1D4ED8),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'Date: $todayLabel',
                                    style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Patient Header Card ──────────────────────────────────────
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      Container(
                        height: 6,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF1E4DA1), Color(0xFF0EA5E9)],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF1E4DA1),
                                    Color(0xFF0EA5E9),
                                  ],
                                ),
                              ),
                              child: const CircleAvatar(
                                radius: 32,
                                backgroundColor: Color(0xFFE8F1FF),
                                child: Icon(
                                  Icons.person,
                                  size: 32,
                                  color: Color(0xFF1E4DA1),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      Text(
                                        _nameCtrl.text.trim().isEmpty
                                            ? 'Unnamed Patient'
                                            : _nameCtrl.text.trim(),
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEE2E2),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFFCA5A5),
                                          ),
                                        ),
                                        child: Text(
                                          'PATIENT ID: $patientLabel',
                                          style: const TextStyle(
                                            color: Color(0xFFDC2626),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 11,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      if (widget.isNewRecord)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF3C7),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                            border: Border.all(
                                              color: const Color(0xFFFDE68A),
                                            ),
                                          ),
                                          child: const Text(
                                            'NEW PATIENT',
                                            style: TextStyle(
                                              color: Color(0xFFB45309),
                                              fontWeight: FontWeight.w700,
                                              fontSize: 11,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      _patientMetaChip(
                                        Icons.cake_outlined,
                                        '${_ageCtrl.text.trim().isEmpty ? '-' : _ageCtrl.text.trim()} yrs',
                                      ),
                                      const SizedBox(width: 10),
                                      _patientMetaChip(
                                        Icons.wc_outlined,
                                        _gender,
                                      ),
                                      const SizedBox(width: 10),
                                      _patientMetaChip(
                                        Icons.bloodtype_outlined,
                                        'Blood: $_bloodGroup',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Wrap(
                              spacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                      color: Color(0xFF2563EB),
                                    ),
                                    foregroundColor: const Color(0xFF2563EB),
                                  ),
                                  onPressed: () {},
                                  icon: const Icon(
                                    Icons.history_rounded,
                                    size: 16,
                                  ),
                                  label: const Text('History'),
                                ),
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                  ),
                                  onPressed: () {},
                                  icon: const Icon(
                                    Icons.science_outlined,
                                    size: 16,
                                  ),
                                  label: const Text('Lab Results'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 1100;

                    // ── LEFT PANE ──────────────────────────────────────────
                    final leftPane = Column(
                      children: [
                        _sectionCard(
                          context,
                          icon: Icons.medical_information_outlined,
                          iconColor: const Color(0xFF7C3AED),
                          iconBg: const Color(0xFFF5F3FF),
                          title: 'Diagnosis & Chief Complaint',
                          child: Column(
                            children: [
                              TextField(
                                controller: _diagnosisCtrl,
                                maxLines: 6,
                                style: const TextStyle(fontSize: 14),
                                decoration: InputDecoration(
                                  hintText:
                                      'Enter clinical diagnosis and symptoms...',
                                  filled: true,
                                  fillColor: const Color(0xFFF1F5F9),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF2563EB),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _testCtrl,
                                style: const TextStyle(fontSize: 14),
                                decoration: InputDecoration(
                                  labelText: 'Suggested Tests',
                                  prefixIcon: const Icon(
                                    Icons.biotech_outlined,
                                    size: 18,
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF1F5F9),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF2563EB),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _sectionCard(
                          context,
                          icon: Icons.monitor_heart_outlined,
                          iconColor: const Color(0xFFDC2626),
                          iconBg: const Color(0xFFFFF1F2),
                          title: 'Vitals',
                          child: Row(
                            children: [
                              Expanded(
                                child: _vitalInputField(
                                  controller: _bpCtrl,
                                  label: 'Blood Pressure',
                                  hint: '120/80',
                                  icon: Icons.favorite_outlined,
                                  iconColor: const Color(0xFFDC2626),
                                  bgColor: const Color(0xFFFFF1F2),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _vitalInputField(
                                  controller: _temperatureCtrl,
                                  label: 'Temperature',
                                  hint: '98.6',
                                  suffix: '°F',
                                  icon: Icons.thermostat_outlined,
                                  iconColor: const Color(0xFFEA580C),
                                  bgColor: const Color(0xFFFFF7ED),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );

                    // ── RIGHT PANE ─────────────────────────────────────────
                    final rightPane = _sectionCard(
                      context,
                      icon: Icons.medication_outlined,
                      iconColor: const Color(0xFF0369A1),
                      iconBg: const Color(0xFFE0F2FE),
                      title: 'Medicines, Advice & Signature',
                      trailing: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF2563EB),
                        ),
                        onPressed: () => setState(
                          () => _medications.add(_MedicationRowData()),
                        ),
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        label: const Text('Add Medicine'),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Column headers
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                SizedBox(width: 30),
                                Expanded(
                                  flex: 4,
                                  child: Text(
                                    'Medicine',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2563EB),
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    'Dosage',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2563EB),
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 56),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          ..._medications.asMap().entries.map((entry) {
                            final index = entry.key;
                            final row = entry.value;
                            final selectedDosage = _dosageSummary(row);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  children: [
                                    // Row 1: medicine + dosage summary + remove
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          radius: 14,
                                          backgroundColor: const Color(
                                            0xFFEFF6FF,
                                          ),
                                          child: Text(
                                            '${index + 1}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF2563EB),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          flex: 4,
                                          child: TextField(
                                            controller: row.medicineCtrl,
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                            decoration: InputDecoration(
                                              hintText: 'Medicine name',
                                              hintStyle: const TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFF64748B),
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 14,
                                                  ),
                                              filled: true,
                                              fillColor: const Color(
                                                0xFFF1F5F9,
                                              ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                borderSide: const BorderSide(
                                                  color: Color(0xFFE2E8F0),
                                                ),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                borderSide: const BorderSide(
                                                  color: Color(0xFFE2E8F0),
                                                ),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                borderSide: const BorderSide(
                                                  color: Color(0xFF2563EB),
                                                  width: 1.5,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          flex: 3,
                                          child: Container(
                                            height: 52,
                                            alignment: Alignment.centerLeft,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF1F5F9),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: const Color(0xFFE2E8F0),
                                              ),
                                            ),
                                            child: Text(
                                              selectedDosage.isEmpty
                                                  ? '-'
                                                  : selectedDosage,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFF334155),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Remove',
                                          onPressed: _medications.length <= 1
                                              ? null
                                              : () {
                                                  final removed = _medications
                                                      .removeAt(index);
                                                  removed.dispose();
                                                  setState(() {});
                                                },
                                          icon: Icon(
                                            Icons.delete_outline,
                                            color: _medications.length <= 1
                                                ? const Color(0xFFE2E8F0)
                                                : const Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 10),

                                    // Row 2: dosage selectors
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Wrap(
                                        spacing: 12,
                                        runSpacing: 8,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          ...row.times.keys.map(
                                            (key) => FilterChip(
                                              label: Text(key),
                                              selected: row.times[key] ?? false,
                                              onSelected: (selected) {
                                                setState(() {
                                                  row.times[key] = selected;
                                                });
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 10),

                                    // Row 3: before/after + duration
                                    Row(
                                      children: [
                                        Expanded(
                                          flex: 4,
                                          child: SegmentedButton<String>(
                                            segments: const [
                                              ButtonSegment<String>(
                                                value: 'before',
                                                label: Text('Before meal'),
                                              ),
                                              ButtonSegment<String>(
                                                value: 'after',
                                                label: Text('After meal'),
                                              ),
                                            ],
                                            selected: {row.mealTiming},
                                            onSelectionChanged: (selection) {
                                              setState(() {
                                                row.mealTiming =
                                                    selection.first;
                                              });
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          flex: 2,
                                          child: TextField(
                                            controller: row.durationCtrl,
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                            decoration: InputDecoration(
                                              hintText: 'Duration',
                                              hintStyle: const TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFF64748B),
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 14,
                                                  ),
                                              filled: true,
                                              fillColor: const Color(
                                                0xFFF1F5F9,
                                              ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                borderSide: const BorderSide(
                                                  color: Color(0xFFE2E8F0),
                                                ),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                borderSide: const BorderSide(
                                                  color: Color(0xFFE2E8F0),
                                                ),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                borderSide: const BorderSide(
                                                  color: Color(0xFF2563EB),
                                                  width: 1.5,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 8),

                                    // Row 4: optional instruction/time note
                                    TextField(
                                      controller: row.mealTimeCtrl,
                                      style: const TextStyle(fontSize: 13),
                                      decoration: InputDecoration(
                                        hintText: 'Instruction / time note',
                                        hintStyle: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF94A3B8),
                                        ),
                                        filled: true,
                                        fillColor: const Color(0xFFF1F5F9),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 14,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Color(0xFFE2E8F0),
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Color(0xFFE2E8F0),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Color(0xFF2563EB),
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 16),
                          const Divider(color: Color(0xFFE2E8F0)),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.tips_and_updates_outlined,
                                  size: 16,
                                  color: Color(0xFF15803D),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Advice & Lifestyle Changes',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _adviceCtrl,
                            maxLines: 4,
                            style: const TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              hintText:
                                  'Advise on diet, rest, or follow-up tests...',
                              filled: true,
                              fillColor: const Color(0xFFF0FDF4),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: Color(0xFFBBF7D0),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: Color(0xFFBBF7D0),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: Color(0xFF15803D),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: 220,
                            child: TextField(
                              controller: _nextVisitCtrl,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontSize: 14),
                              decoration: InputDecoration(
                                labelText: 'Next Visit (Days)',
                                hintText: 'e.g. 7',
                                suffixText: 'days',
                                prefixIcon: const Icon(
                                  Icons.event_available_outlined,
                                  size: 18,
                                  color: Color(0xFF2563EB),
                                ),
                                filled: true,
                                fillColor: const Color(0xFFEFF6FF),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFBFDBFE),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFBFDBFE),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF2563EB),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: Color(0xFFBFDBFE),
                                  ),
                                  foregroundColor: const Color(0xFF1D4ED8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 14,
                                  ),
                                ),
                                onPressed: _downloadPrescription,
                                icon: const Icon(
                                  Icons.download_outlined,
                                  size: 17,
                                ),
                                label: const Text('Download PDF'),
                              ),
                              const SizedBox(width: 10),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: Color(0xFFCBD5E1),
                                  ),
                                  foregroundColor: const Color(0xFF334155),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 14,
                                  ),
                                ),
                                onPressed: _printPrescription,
                                icon: const Icon(
                                  Icons.print_outlined,
                                  size: 17,
                                ),
                                label: const Text('Print / Save PDF'),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF1E4DA1),
                                      Color(0xFF0369A1),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 22,
                                      vertical: 14,
                                    ),
                                  ),
                                  onPressed: _isSaving
                                      ? null
                                      : () => _savePrescription(),
                                  icon: _isSaving
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.save_outlined,
                                          size: 17,
                                        ),
                                  label: Text(
                                    _isSaving
                                        ? 'Saving...'
                                        : 'Save, E-Sign & Print',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );

                    if (isCompact) {
                      return Column(
                        children: [
                          leftPane,
                          const SizedBox(height: 12),
                          rightPane,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: leftPane),
                        const SizedBox(width: 14),
                        Expanded(flex: 2, child: rightPane),
                      ],
                    );
                  },
                ),
              ],
            ),
    );
  }

  // ── Private helper widgets ──────────────────────────────────────────

  Widget _sectionCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: iconColor),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                if (trailing != null) ...[const Spacer(), trailing],
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }

  Widget _patientMetaChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: const Color(0xFF64748B)),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  Widget _vitalInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? suffix,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: bgColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: iconColor),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: iconColor,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          TextField(
            controller: controller,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w400,
                fontSize: 16,
              ),
              suffixText: suffix,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 6),
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
            ),
          ),
        ],
      ),
    );
  }
}

class _MedicationRowData {
  _MedicationRowData();

  final medicineCtrl = TextEditingController();
  final durationCtrl = TextEditingController();
  final mealTimeCtrl = TextEditingController();

  Map<String, bool> times = {
    'Morning': true,
    'Afternoon': false,
    'Night': true,
  };

  bool isFourTimes = false;
  String mealTiming = 'after';

  void dispose() {
    medicineCtrl.dispose();
    durationCtrl.dispose();
    mealTimeCtrl.dispose();
  }
}
