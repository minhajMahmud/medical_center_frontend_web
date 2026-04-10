import 'package:backend_client/backend_client.dart';
import 'package:flutter/foundation.dart';

import '../models/appointment.dart';
import '../models/doctor.dart';
import '../services/appointment_service.dart';

class AppointmentController extends ChangeNotifier {
  AppointmentController(this._service);

  final AppointmentService _service;

  bool isLoading = false;
  String? error;

  List<DoctorModel> doctors = [];
  List<AppointmentModel> appointments = [];
  List<PatientReportDto> reports = [];

  Future<void> loadDashboardData() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final doctorRows = await _service.getDoctors();
      doctors = doctorRows.map(DoctorModel.fromStaffInfo).toList();
    } catch (e) {
      error = 'Failed to load doctors from backend.';
      debugPrint('loadDashboardData doctors failed: $e');
    }

    try {
      final doctorNameById = <int, String>{
        for (final doctor in doctors)
          if (doctor.userId != null) doctor.userId!: doctor.name,
      };
      appointments = await _service.getAppointments(
        doctorNameById: doctorNameById,
      );
    } catch (e) {
      error ??= 'Failed to load appointment requests.';
      debugPrint('loadDashboardData appointments failed: $e');
    }

    try {
      reports = await _service.getMedicalReports();
    } catch (e) {
      debugPrint('loadDashboardData reports failed: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<int> createAppointmentRequest({
    required int doctorId,
    required DateTime appointmentDate,
    required String appointmentTimeLabel,
    required String reason,
    String? notes,
    required bool urgent,
    String mode = 'In-Person',
  }) async {
    try {
      final requestId = await _service.createAppointmentRequest(
        doctorId: doctorId,
        appointmentDate: appointmentDate,
        appointmentTimeLabel: appointmentTimeLabel,
        reason: reason,
        notes: notes,
        urgent: urgent,
        mode: mode,
      );
      return requestId;
    } catch (_) {
      return -1;
    }
  }

  Future<bool> cancelMyAppointmentRequest({
    required int appointmentRequestId,
    String? reason,
  }) async {
    try {
      final ok = await _service.cancelMyAppointmentRequest(
        appointmentRequestId: appointmentRequestId,
        reason: reason,
      );
      if (ok) {
        await loadDashboardData();
      }
      return ok;
    } catch (_) {
      return false;
    }
  }

  Future<bool> rescheduleMyAppointmentRequest({
    required int appointmentRequestId,
    required DateTime appointmentDate,
    required String appointmentTimeLabel,
    String? notes,
  }) async {
    try {
      final ok = await _service.rescheduleMyAppointmentRequest(
        appointmentRequestId: appointmentRequestId,
        appointmentDate: appointmentDate,
        appointmentTimeLabel: appointmentTimeLabel,
        notes: notes,
      );
      if (ok) {
        await loadDashboardData();
      }
      return ok;
    } catch (_) {
      return false;
    }
  }
}
