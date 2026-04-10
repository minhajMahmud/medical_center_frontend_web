import 'package:backend_client/backend_client.dart';

class AppointmentModel {
  AppointmentModel({
    required this.id,
    required this.doctorName,
    required this.date,
    this.timeLabel,
    this.status,
    this.reason,
    this.declineReason,
    this.urgent = false,
    this.mode,
    this.type,
  });

  final int id;
  final String doctorName;
  final DateTime date;
  final String? timeLabel;
  final String? status;
  final String? reason;
  final String? declineReason;
  final bool urgent;
  final String? mode;
  final String? type;

  factory AppointmentModel.fromPrescription(PrescriptionList p) =>
      AppointmentModel(
        id: p.prescriptionId,
        doctorName: p.doctorName,
        date: p.date,
        type: p.sourceReportType,
      );

  factory AppointmentModel.fromAppointmentRequest(
    AppointmentRequestItem item,
    String doctorName,
  ) => AppointmentModel(
    id: item.appointmentRequestId,
    doctorName: doctorName,
    date: item.appointmentDate,
    timeLabel: item.appointmentTime,
    status: item.status,
    reason: item.reason,
    declineReason: item.declineReason,
    urgent: item.urgent,
    mode: item.mode,
  );
}
