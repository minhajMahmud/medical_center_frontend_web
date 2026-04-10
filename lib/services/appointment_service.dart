import 'package:backend_client/backend_client.dart';
import 'package:intl/intl.dart';

import '../models/appointment.dart';
import 'api_service.dart';

class AppointmentService {
  final _client = ApiService.instance.client;

  Future<List<StaffInfo>> getDoctors() async {
    final rows = await _client.patient.getMedicalStaff();
    return rows.where(_isDoctorOnly).toList();
  }

  bool _isDoctorOnly(StaffInfo staff) {
    final designation = (staff.designation ?? '').toLowerCase().trim();
    final qualification = (staff.qualification ?? '').toLowerCase().trim();
    final haystack = '$designation $qualification';

    // Hard exclusions for non-doctor roles.
    const nonDoctorKeywords = [
      'admin',
      'lab',
      'dispenser',
      'pharmac',
      'nurse',
      'reception',
      'technician',
      'staff',
      'account',
      'manager',
    ];
    if (nonDoctorKeywords.any(haystack.contains)) return false;

    // Strict doctor-focused signals.
    final doctorByDesignation =
        designation.contains('doctor') ||
        designation.contains('dr.') ||
        designation == 'dr';

    final doctorByQualification = [
      'mbbs',
      'fcps',
      'md',
      'ms',
      'dm',
      'mch',
      'bds',
      'dgo',
    ].any(qualification.contains);

    return doctorByDesignation || doctorByQualification;
  }

  Future<List<AppointmentModel>> getAppointments({
    required Map<int, String> doctorNameById,
  }) async {
    try {
      final rows = await _client.patient.getMyAppointmentRequests();
      return rows
          .map(
            (item) => AppointmentModel.fromAppointmentRequest(
              item,
              doctorNameById[item.doctorId] ?? 'Doctor #${item.doctorId}',
            ),
          )
          .toList();
    } catch (_) {
      final legacy = await _client.patient.getMyPrescriptionList();
      return legacy.map(AppointmentModel.fromPrescription).toList();
    }
  }

  Future<List<PatientReportDto>> getMedicalReports() =>
      _client.patient.getMyLabReports();

  Future<int> createAppointmentRequest({
    required int doctorId,
    required DateTime appointmentDate,
    required String appointmentTimeLabel,
    required String reason,
    String? notes,
    required bool urgent,
    String mode = 'In-Person',
  }) async {
    final parsed = DateFormat('hh:mm a').parse(appointmentTimeLabel);
    final normalizedTime = DateFormat('HH:mm:ss').format(parsed);

    return _client.patient.createAppointmentRequest(
      doctorId: doctorId,
      appointmentDate: DateTime(
        appointmentDate.year,
        appointmentDate.month,
        appointmentDate.day,
      ),
      appointmentTime: normalizedTime,
      reason: reason,
      notes: notes,
      urgent: urgent,
      mode: mode,
    );
  }

  Future<bool> cancelMyAppointmentRequest({
    required int appointmentRequestId,
    String? reason,
  }) => _client.patient.cancelMyAppointmentRequest(
    appointmentRequestId: appointmentRequestId,
    reason: reason,
  );

  Future<bool> rescheduleMyAppointmentRequest({
    required int appointmentRequestId,
    required DateTime appointmentDate,
    required String appointmentTimeLabel,
    String? notes,
  }) async {
    final parsed = DateFormat('hh:mm a').parse(appointmentTimeLabel);
    final normalizedTime = DateFormat('HH:mm:ss').format(parsed);

    return _client.patient.rescheduleMyAppointmentRequest(
      appointmentRequestId: appointmentRequestId,
      appointmentDate: DateTime(
        appointmentDate.year,
        appointmentDate.month,
        appointmentDate.day,
      ),
      appointmentTime: normalizedTime,
      notes: notes,
    );
  }
}
