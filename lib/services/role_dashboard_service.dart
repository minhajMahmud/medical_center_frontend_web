import 'package:backend_client/backend_client.dart';
import 'dart:convert';

import 'api_service.dart';

class RoleDashboardService {
  final _client = ApiService.instance.client;
  final _keyManager = ApiService.instance.authKeyManager;

  String? _currentEmailFromToken(String? token) {
    if (token == null || token.isEmpty) return null;
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final normalized = base64Url.normalize(parts[1]);
      final payload = utf8.decode(base64Url.decode(normalized));
      final map = jsonDecode(payload);
      if (map is Map<String, dynamic>) {
        final sub = map['sub'];
        return sub?.toString();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _getCurrentEmail() async {
    final token = await _keyManager.get();
    return _currentEmailFromToken(token);
  }

  // Patient
  Future<PatientProfile?> getPatientProfile() =>
      _client.patient.getPatientProfile();
  Future<List<StaffInfo>> getPatientDoctors() =>
      _client.patient.getMedicalStaff();
  Future<List<AppointmentRequestItem>> getPatientAppointments() =>
      _client.patient.getMyAppointmentRequests();
  Future<List<PrescriptionList>> getPatientAppointmentsLegacy() =>
      _client.patient.getMyPrescriptionList();
  Future<List<PrescriptionList>> getPatientPrescriptions() =>
      _client.patient.getMyPrescriptionList();
  Future<PrescriptionDetail?> getPatientPrescriptionDetail(
    int prescriptionId,
  ) => _client.patient.getPrescriptionDetail(prescriptionId);
  Future<List<PatientReportDto>> getPatientReports() =>
      _client.patient.getMyLabReports();
  Future<List<LabTests>> getLabTests() => _client.patient.listTests();
  Future<List<OndutyStaff>> getOnDutyStaff() =>
      _client.patient.getOndutyStaff();
  Future<List<AmbulanceContact>> getAmbulanceContacts() =>
      _client.patient.getAmbulanceContacts();
  Future<List<NotificationInfo>> getPatientNotifications() =>
      _client.notification.getMyNotifications(limit: 50);
  Future<Map<String, int>> getNotificationCounts() =>
      _client.notification.getMyNotificationCounts();
  Future<bool> markNotificationAsRead(int notificationId) =>
      _client.notification.markAsRead(notificationId: notificationId);
  Future<bool> markAllNotificationsAsRead() =>
      _client.notification.markAllAsRead();

  Future<String> updatePatientProfile({
    required String name,
    required String phone,
    String? bloodGroup,
    DateTime? dateOfBirth,
    String? gender,
    String? profileImageUrl,
  }) => _client.patient.updatePatientProfile(
    name,
    phone,
    bloodGroup,
    dateOfBirth,
    gender,
    profileImageUrl,
  );

  // Doctor
  Future<DoctorHomeData> getDoctorHome() => _client.doctor.getDoctorHomeData();
  Future<DoctorProfile?> getDoctorProfile() =>
      _client.doctor.getDoctorProfile(0);
  Future<bool> updateDoctorProfile({
    required String name,
    required String email,
    required String phone,
    required String qualification,
    required String designation,
    String? profilePictureUrl,
  }) => _client.doctor.updateDoctorProfile(
    0,
    name,
    email,
    phone,
    profilePictureUrl,
    designation,
    qualification,
    null,
  );
  Future<List<PatientPrescriptionListItem>> getDoctorPrescriptions({
    String? query,
    int limit = 30,
  }) => _client.doctor.getPatientPrescriptionList(
    query: query,
    limit: limit,
    offset: 0,
  );
  Future<List<PatientExternalReport>> getDoctorReports() =>
      _client.doctor.getReportsForDoctor(0);
  Future<bool> markDoctorReportReviewed(int reportId) =>
      _client.doctor.markReportReviewed(reportId);
  Future<bool> submitDoctorReview({
    required int reportId,
    required String notes,
    required String action,
    required bool visibleToPatient,
  }) => _client.doctor.submitDoctorReview(
    reportId,
    notes,
    action,
    visibleToPatient,
  );
  Future<List<AppointmentRequestItem>> getDoctorAppointmentRequests({
    String? status,
    String? query,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      return await _client.doctor.getAppointmentRequests(
        status: status,
        query: query,
        limit: limit,
        offset: offset,
      );
    } catch (_) {
      return const [];
    }
  }

  Future<bool> updateDoctorAppointmentRequestStatus({
    required int appointmentRequestId,
    required String status,
    String? declineReason,
  }) => _client.doctor.updateAppointmentRequestStatus(
    appointmentRequestId: appointmentRequestId,
    status: status,
    declineReason: declineReason,
  );
  Future<Map<String, String?>> getDoctorPatientByPhoneOrName(String query) =>
      _client.doctor.getPatientByPhone(query);
  Future<int> createDoctorPrescription({
    required Prescription prescription,
    required List<PrescribedItem> items,
    required String patientPhone,
  }) => _client.doctor.createPrescription(prescription, items, patientPhone);
  Future<PatientPrescriptionDetails?> getDoctorPrescriptionDetails(
    int prescriptionId,
  ) => _client.doctor.getPrescriptionDetails(prescriptionId: prescriptionId);

  // Admin
  Future<AdminDashboardOverview> getAdminOverview() =>
      _client.adminReportEndpoints.getAdminDashboardOverview();
  Future<DashboardAnalytics> getAdminAnalytics() =>
      _client.adminReportEndpoints.getDashboardAnalytics();
  Future<List<AuditEntry>> getRecentAudit() =>
      _client.adminEndpoints.getRecentAuditLogs(24, 30);
  Future<List<UserListItem>> getAdminUsers({
    String role = 'ALL',
    int limit = 100,
  }) => _client.adminEndpoints.listUsersByRole(role, limit);
  Future<String> createAdminUserWithPassword({
    required String name,
    required String email,
    required String password,
    required String role,
    String? phone,
  }) => _client.adminEndpoints.createUserWithPassword(
    name,
    email,
    password,
    role,
    phone,
  );
  Future<bool> toggleAdminUserActive(String userId) =>
      _client.adminEndpoints.toggleUserActive(userId);
  Future<List<InventoryItemInfo>> getAdminInventory() =>
      _client.adminInventoryEndpoints.listInventoryItems();
  Future<List<InventoryCategory>> getAdminInventoryCategories() =>
      _client.adminInventoryEndpoints.listInventoryCategories();
  Future<bool> addAdminInventoryCategory({
    required String name,
    String? description,
  }) => _client.adminInventoryEndpoints.addInventoryCategory(name, description);
  Future<bool> addAdminInventoryItem({
    required int categoryId,
    required String itemName,
    required String unit,
    required int minimumStock,
    required int initialStock,
    required bool canRestockDispenser,
  }) => _client.adminInventoryEndpoints.addInventoryItem(
    categoryId: categoryId,
    itemName: itemName,
    unit: unit,
    minimumStock: minimumStock,
    initialStock: initialStock,
    canRestockDispenser: canRestockDispenser,
  );
  Future<bool> updateAdminInventoryStock({
    required int itemId,
    required int quantity,
    required String type,
  }) => _client.adminInventoryEndpoints.updateInventoryStock(
    itemId: itemId,
    quantity: quantity,
    type: type,
  );
  Future<bool> updateAdminDispenserRestockFlag({
    required int itemId,
    required bool canRestock,
  }) => _client.adminInventoryEndpoints.updateDispenserRestockFlag(
    itemId: itemId,
    canRestock: canRestock,
  );
  Future<bool> updateAdminMinimumThreshold({
    required int itemId,
    required int newThreshold,
  }) => _client.adminInventoryEndpoints.updateMinimumThreshold(
    itemId: itemId,
    newThreshold: newThreshold,
  );
  Future<List<Rosterlists>> getAdminStaffList({int limit = 200}) =>
      _client.adminEndpoints.listStaff(limit);
  Future<List<Roster>> getAdminRosters({
    DateTime? fromDate,
    DateTime? toDate,
    String? staffId,
    bool includeDeleted = false,
  }) => _client.adminEndpoints.getRosters(
    staffId,
    fromDate,
    toDate,
    includeDeleted: includeDeleted,
  );
  Future<bool> saveAdminRoster({
    String rosterId = '',
    required String staffId,
    required String shiftType,
    required DateTime shiftDate,
    String timeRange = '',
    String status = 'ACTIVE',
    String? approvedBy,
  }) => _client.adminEndpoints.saveRoster(
    rosterId,
    staffId,
    shiftType,
    shiftDate,
    timeRange,
    status,
    approvedBy,
  );
  Future<bool> deleteAdminRoster(int rosterId) =>
      _client.adminEndpoints.deleteRoster(rosterId);
  Future<List<AmbulanceContact>> getAdminAmbulanceContacts() =>
      _client.patient.getAmbulanceContacts();
  Future<bool> addAdminAmbulanceContact({
    required String title,
    required String phoneBn,
    required String phoneEn,
    required bool isPrimary,
  }) => _client.adminEndpoints.addAmbulanceContact(
    title,
    phoneBn,
    phoneEn,
    isPrimary,
  );
  Future<bool> updateAdminAmbulanceContact({
    required int id,
    required String title,
    required String phoneBn,
    required String phoneEn,
    required bool isPrimary,
  }) => _client.adminEndpoints.updateAmbulanceContact(
    id,
    title,
    phoneBn,
    phoneEn,
    isPrimary,
  );
  Future<AdminProfileRespond?> getAdminProfile() async {
    final email = await _getCurrentEmail();
    if (email == null || email.isEmpty) return null;
    return _client.adminEndpoints.getAdminProfile(email);
  }

  Future<String> updateAdminProfile({
    required String name,
    required String phone,
    String? designation,
    String? qualification,
    String? profilePictureUrl,
  }) async {
    final email = await _getCurrentEmail();
    if (email == null || email.isEmpty) {
      return 'Unable to resolve current user email';
    }
    return _client.adminEndpoints.updateAdminProfile(
      email,
      name,
      phone,
      profilePictureUrl,
      designation,
      qualification,
    );
  }

  // Lab
  Future<LabToday> getLabSummary() => _client.lab.getLabHomeTwoDaySummary();
  Future<List<LabTenHistory>> getLabHistory() =>
      _client.lab.getLast10TestHistory();
  Future<List<TestResult>> getAllLabResults() =>
      _client.lab.getAllTestResults();
  Future<List<LabTests>> getAllLabTests() => _client.lab.getAllLabTests();
  Future<LabAnalyticsSnapshot> getLabAnalyticsSnapshot({
    DateTime? fromDate,
    DateTime? toDateExclusive,
    String patientType = 'ALL',
  }) => _client.lab.getAnalyticsSnapshot(
    fromDate: fromDate,
    toDateExclusive: toDateExclusive,
    patientType: patientType,
  );
  Future<StaffProfileDto?> getLabStaffProfile() =>
      _client.lab.getStaffProfile();
  Future<bool> updateLabStaffProfile({
    required String name,
    required String email,
    required String phone,
    required String qualification,
    required String designation,
    String? profilePictureUrl,
  }) => _client.lab.updateStaffProfile(
    name: name,
    phone: phone,
    email: email,
    designation: designation,
    qualification: qualification,
    profilePictureUrl: profilePictureUrl,
  );
  Future<String> changeMyPassword({
    required String currentPassword,
    required String newPassword,
  }) => _client.password.changePassword(
    currentPassword: currentPassword,
    newPassword: newPassword,
  );

  // Dispenser
  Future<DispenserProfileR?> getDispenserProfile() =>
      _client.dispenser.getDispenserProfile();
  Future<String> updateDispenserProfile({
    required String name,
    required String phone,
    required String qualification,
    required String designation,
    String? profilePictureUrl,
  }) => _client.dispenser.updateDispenserProfile(
    name: name,
    phone: phone,
    qualification: qualification,
    designation: designation,
    profilePictureUrl: profilePictureUrl,
  );
  Future<List<InventoryItemInfo>> getDispenserStock() =>
      _client.dispenser.listInventoryItems();
  Future<List<DispenseHistoryEntry>> getDispenserHistory() =>
      _client.dispenser.getDispenserDispenseHistory(limit: 30);
  Future<List<Prescription>> getDispenserPendingPrescriptions() =>
      _client.dispenser.getPendingPrescriptions();
  Future<PrescriptionDetail?> getDispenserPrescriptionDetail(
    int prescriptionId,
  ) => _client.dispenser.getPrescriptionDetail(prescriptionId);
  Future<List<InventoryItemInfo>> searchDispenserInventoryItems(String query) =>
      _client.dispenser.searchInventoryItems(query);
  Future<bool> dispensePrescription({
    required int prescriptionId,
    int dispenserId = 0,
    required List<DispenseItemRequest> items,
  }) => _client.dispenser.dispensePrescription(
    prescriptionId: prescriptionId,
    dispenserId: dispenserId,
    items: items,
  );
}
