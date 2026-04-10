import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/appointment_controller.dart';
import '../../models/appointment.dart';
import '../../models/doctor.dart';
import '../../widgets/common/dashboard_shell.dart';

class AppointmentsPage extends StatefulWidget {
  const AppointmentsPage({super.key});

  @override
  State<AppointmentsPage> createState() => _AppointmentsPageState();
}

class _AppointmentsPageState extends State<AppointmentsPage> {
  final TextEditingController _notesController = TextEditingController();
  final Set<int> _busyRequestIds = <int>{};

  int _selectedDoctor = 0;
  late DateTime _selectedDate;
  int _selectedTimeIndex = 1;
  String _selectedReason = 'Regular Checkup';
  bool _urgent = false;

  final List<String> _timeSlots = const [
    '09:00 AM',
    '10:30 AM',
    '11:00 AM',
    '01:30 PM',
    '02:45 PM',
    '04:00 PM',
  ];

  final List<String> _reasons = const [
    'Regular Checkup',
    'Follow-up Visit',
    'Chest Pain / Cardiac Concern',
    'Neurological Symptoms',
    'Dental Pain',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 3));
    Future.microtask(() {
      if (!mounted) return;
      context.read<AppointmentController>().loadDashboardData();
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _onConfirm(List<DoctorModel> doctors) async {
    if (doctors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No doctor is currently available.')),
      );
      return;
    }

    final selectedDate = _selectedDate;
    final selectedTime = _timeSlots[_selectedTimeIndex];
    final selectedDoctorModel = doctors[_selectedDoctor];
    if (selectedDoctorModel.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Doctor identity is missing from backend response. Please refresh or restart backend.',
          ),
        ),
      );
      return;
    }
    final doctor = selectedDoctorModel.name;

    final requestId = await context
        .read<AppointmentController>()
        .createAppointmentRequest(
          doctorId: selectedDoctorModel.userId!,
          appointmentDate: selectedDate,
          appointmentTimeLabel: selectedTime,
          reason: _selectedReason,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          urgent: _urgent,
          mode: 'In-Person',
        );

    if (!mounted) return;

    if (requestId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Failed to create appointment request. Please try again.',
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Appointment request #$requestId created for ${DateFormat('dd MMM yyyy').format(selectedDate)} at $selectedTime with Dr. $doctor.',
        ),
      ),
    );
  }

  void _onSaveLater() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Draft appointment saved.')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final desktop = MediaQuery.sizeOf(context).width > 1100;
    final controller = context.watch<AppointmentController>();
    final doctors = controller.doctors;

    if (_selectedDoctor >= doctors.length && doctors.isNotEmpty) {
      _selectedDoctor = 0;
    }

    return DashboardShell(
      child: ListView(
        children: [
          Text(
            'Book an Appointment',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Portal  >  Appointments  >  New Booking',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 14),
          const SizedBox(height: 14),
          _buildDoctorSection(theme, controller, doctors),
          const SizedBox(height: 14),
          desktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildDateSection(theme)),
                    const SizedBox(width: 14),
                    Expanded(child: _buildTimeSection()),
                  ],
                )
              : Column(
                  children: [
                    _buildDateSection(theme),
                    const SizedBox(height: 14),
                    _buildTimeSection(),
                  ],
                ),
          const SizedBox(height: 14),
          _buildReasonSection(theme),
          const SizedBox(height: 14),
          Row(
            children: [
              OutlinedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Back'),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: _onSaveLater,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                ),
                child: const Text('Save for Later'),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: () async => _onConfirm(doctors),
                child: const Text('Confirm Appointment'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildMyRequestsSection(theme, controller.appointments),
        ],
      ),
    );
  }

  Widget _buildMyRequestsSection(
    ThemeData theme,
    List<AppointmentModel> appointments,
  ) {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.assignment_rounded,
                size: 18,
                color: Color(0xFF2563EB),
              ),
              const SizedBox(width: 8),
              Text(
                'My Appointment Requests',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (appointments.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Text('No appointment requests found yet.'),
            )
          else
            ...appointments.map<Widget>((item) {
              final status = (item.status ?? 'PENDING')
                  .toString()
                  .toUpperCase();
              final busy = _busyRequestIds.contains(item.id);
              final isConfirmed = status == 'CONFIRMED';
              final isDeclined = status == 'DECLINED';
              final canEdit = status == 'PENDING' || status == 'CONFIRMED';
              final chipColor = isConfirmed
                  ? const Color(0xFF16A34A)
                  : isDeclined
                  ? const Color(0xFFDC2626)
                  : const Color(0xFF2563EB);
              final chipBg = isConfirmed
                  ? const Color(0xFFECFDF3)
                  : isDeclined
                  ? const Color(0xFFFEF2F2)
                  : const Color(0xFFEFF6FF);

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
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
                            'Dr. ${item.doctorName}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${DateFormat('dd MMM yyyy').format(item.date)} • ${item.timeLabel ?? '-'}',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                          if ((item.reason ?? '').toString().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              item.reason!,
                              style: const TextStyle(
                                color: Color(0xFF334155),
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                          if ((item.declineReason ?? '')
                              .toString()
                              .isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Reason: ${item.declineReason}',
                              style: const TextStyle(
                                color: Color(0xFF991B1B),
                                fontSize: 12,
                              ),
                            ),
                          ],
                          if (canEdit) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: busy
                                      ? null
                                      : () => _onRescheduleRequest(item),
                                  icon: const Icon(
                                    Icons.edit_calendar_rounded,
                                    size: 16,
                                  ),
                                  label: const Text('Reschedule'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: busy
                                      ? null
                                      : () => _onCancelRequest(item),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFB91C1C),
                                    side: const BorderSide(
                                      color: Color(0xFFFCA5A5),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.cancel_outlined,
                                    size: 16,
                                  ),
                                  label: const Text('Cancel'),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: chipBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: chipColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildDoctorSection(
    ThemeData theme,
    AppointmentController controller,
    List<DoctorModel> doctors,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.medical_services_rounded,
                color: Color(0xFF2563EB),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available Doctors',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Choose a doctor to continue your appointment booking.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF1FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${doctors.length} available',
                  style: const TextStyle(
                    color: Color(0xFF1D4ED8),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Refresh doctors',
                onPressed: controller.isLoading
                    ? null
                    : () => controller.loadDashboardData(),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (controller.isLoading && doctors.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          )
        else if (controller.error != null && doctors.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDA4AF)),
            ),
            child: Text(
              controller.error!,
              style: const TextStyle(color: Color(0xFF9F1239)),
            ),
          )
        else if (doctors.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Text('No available doctors found in database.'),
          )
        else
          ...List.generate(doctors.length, (index) {
            final doctor = doctors[index];
            final selected = _selectedDoctor == index;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _selectedDoctor = index),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF2F80ED)
                          : const Color(0xFFE2E8F0),
                      width: selected ? 1.4 : 1,
                    ),
                    boxShadow: selected
                        ? const [
                            BoxShadow(
                              color: Color(0x1A2563EB),
                              blurRadius: 16,
                              offset: Offset(0, 6),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0xFFEAF1FF),
                        backgroundImage:
                            (doctor.profilePictureUrl != null &&
                                doctor.profilePictureUrl!.isNotEmpty)
                            ? NetworkImage(doctor.profilePictureUrl!)
                            : null,
                        child:
                            (doctor.profilePictureUrl == null ||
                                doctor.profilePictureUrl!.isEmpty)
                            ? Text(
                                doctor.name
                                    .trim()
                                    .split(' ')
                                    .where((e) => e.isNotEmpty)
                                    .take(2)
                                    .map((e) => e[0])
                                    .join()
                                    .toUpperCase(),
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dr. ${doctor.name}',
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              doctor.designation?.trim().isNotEmpty == true
                                  ? doctor.designation!
                                  : 'Specialist',
                              style: const TextStyle(
                                color: Color(0xFF1D4ED8),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (doctor.qualification?.trim().isNotEmpty == true)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  doctor.qualification!,
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.call_outlined,
                                  size: 14,
                                  color: Color(0xFF64748B),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  doctor.phone,
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      selected
                          ? const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF16A34A),
                              size: 22,
                            )
                          : const Icon(
                              Icons.radio_button_unchecked_rounded,
                              color: Color(0xFF94A3B8),
                              size: 22,
                            ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildDateSection(ThemeData theme) {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SELECT DATE',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w700,
              letterSpacing: .8,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_month_rounded,
                  color: Color(0xFF2563EB),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEEE').format(_selectedDate),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('dd MMM yyyy').format(_selectedDate),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final now = DateTime.now();
                    final firstDate = DateTime(now.year, now.month, now.day);
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: firstDate,
                      lastDate: firstDate.add(const Duration(days: 365)),
                      helpText: 'Select appointment date',
                    );

                    if (picked != null) {
                      setState(() {
                        _selectedDate = DateTime(
                          picked.year,
                          picked.month,
                          picked.day,
                        );
                      });
                    }
                  },
                  icon: const Icon(Icons.edit_calendar_rounded, size: 16),
                  label: const Text('Pick'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSection() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AVAILABLE TIME SLOTS',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w700,
              letterSpacing: .8,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(_timeSlots.length, (index) {
              final selected = _selectedTimeIndex == index;
              return SizedBox(
                width: 110,
                child: OutlinedButton(
                  onPressed: () => setState(() => _selectedTimeIndex = index),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: selected
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF0F172A),
                    side: BorderSide(
                      color: selected
                          ? const Color(0xFF2F80ED)
                          : const Color(0xFFD9E2EF),
                    ),
                  ),
                  child: Text(
                    _timeSlots[index],
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonSection(ThemeData theme) {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.notes_rounded,
                size: 18,
                color: Color(0xFF2563EB),
              ),
              const SizedBox(width: 8),
              Text(
                'Reason for Visit',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Primary Symptom or Concern',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedReason,
            items: _reasons
                .map((r) => DropdownMenuItem<String>(value: r, child: Text(r)))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _selectedReason = v);
            },
          ),
          const SizedBox(height: 12),
          const Text(
            'Additional Information (Optional)',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText:
                  'Please describe any symptoms, when they started, and any relevant medical history...',
            ),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _urgent,
            onChanged: (v) => setState(() => _urgent = v ?? false),
            title: const Text(
              'I am experiencing severe symptoms that require immediate attention.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: child,
    );
  }

  Future<void> _onCancelRequest(AppointmentModel item) async {
    final reason = await _askCancelReason();
    if (reason == null) return;
    if (!mounted) return;

    setState(() => _busyRequestIds.add(item.id));
    final ok = await context
        .read<AppointmentController>()
        .cancelMyAppointmentRequest(
          appointmentRequestId: item.id,
          reason: reason,
        );
    if (!mounted) return;
    setState(() => _busyRequestIds.remove(item.id));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Appointment #${item.id} cancelled.'
              : 'Could not cancel appointment #${item.id}.',
        ),
      ),
    );
  }

  Future<void> _onRescheduleRequest(AppointmentModel item) async {
    final payload = await _askReschedulePayload(item);
    if (payload == null) return;
    if (!mounted) return;

    setState(() => _busyRequestIds.add(item.id));
    final ok = await context
        .read<AppointmentController>()
        .rescheduleMyAppointmentRequest(
          appointmentRequestId: item.id,
          appointmentDate: payload.$1,
          appointmentTimeLabel: payload.$2,
          notes: payload.$3,
        );
    if (!mounted) return;
    setState(() => _busyRequestIds.remove(item.id));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Appointment #${item.id} rescheduled.'
              : 'Could not reschedule appointment #${item.id}.',
        ),
      ),
    );
  }

  Future<String?> _askCancelReason() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel appointment'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Reason for cancellation (optional)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Confirm Cancel'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<(DateTime, String, String?)?> _askReschedulePayload(
    AppointmentModel item,
  ) async {
    DateTime pickedDate = DateTime(
      item.date.year,
      item.date.month,
      item.date.day,
    );
    String selectedTime = _timeSlots.contains(item.timeLabel)
        ? item.timeLabel!
        : _timeSlots.first;
    final notesController = TextEditingController();

    final result = await showDialog<(DateTime, String, String?)>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('Reschedule appointment'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final now = DateTime.now();
                      final firstDate = DateTime(now.year, now.month, now.day);
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: pickedDate,
                        firstDate: firstDate,
                        lastDate: firstDate.add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setLocalState(() {
                          pickedDate = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                          );
                        });
                      }
                    },
                    icon: const Icon(Icons.calendar_month_rounded, size: 16),
                    label: Text(DateFormat('dd MMM yyyy').format(pickedDate)),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedTime,
                    items: _timeSlots
                        .map(
                          (slot) => DropdownMenuItem<String>(
                            value: slot,
                            child: Text(slot),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setLocalState(() => selectedTime = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'Optional note for doctor',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Back'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop((
                    pickedDate,
                    selectedTime,
                    notesController.text.trim().isEmpty
                        ? null
                        : notesController.text.trim(),
                  )),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    notesController.dispose();
    return result;
  }
}
