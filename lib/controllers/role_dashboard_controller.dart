import 'package:backend_client/backend_client.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/appointment.dart';
import '../models/doctor.dart';
import '../services/role_dashboard_service.dart';

class RoleDashboardController extends ChangeNotifier {
  RoleDashboardController(this._service);

  final RoleDashboardService _service;

  bool isLoading = false;
  String? error;

  // Patient
  // Patient
  PatientProfile? patientProfile;
  List<DoctorModel> patientDoctors = [];
  List<AppointmentModel> patientAppointments = [];
  List<PrescriptionList> patientPrescriptions = [];
  List<PatientReportDto> patientReports = [];
  List<LabTests> patientLabTests = [];
  List<OndutyStaff> patientOnDutyStaff = [];
  List<AmbulanceContact> patientAmbulanceContacts = [];
  List<NotificationInfo> patientNotifications = [];
  List<NotificationInfo> get notifications => patientNotifications;

  // Doctor
  DoctorHomeData? doctorHome;
  DoctorProfile? doctorProfile;
  List<PatientExternalReport> doctorReports = [];
  List<PatientPrescriptionListItem> doctorPrescriptionList = [];
  List<AppointmentRequestItem> doctorAppointmentRequests = [];

  // Admin
  AdminDashboardOverview? adminOverview;
  DashboardAnalytics? adminAnalytics;
  AdminProfileRespond? adminProfile;
  List<AuditEntry> adminAudits = [];
  List<UserListItem> adminUsers = [];
  List<InventoryItemInfo> adminInventory = [];
  List<InventoryCategory> adminInventoryCategories = [];
  List<Roster> adminRosters = [];
  List<Rosterlists> adminRosterStaff = [];
  List<AmbulanceContact> adminAmbulanceContacts = [];

  // Lab
  LabToday? labSummary;
  List<LabTenHistory> labHistory = [];
  List<TestResult> labResults = [];
  List<LabTests> labAvailableTests = [];
  StaffProfileDto? labProfile;
  LabAnalyticsSnapshot? labAnalyticsSnapshot;
  bool isLabAnalyticsLoading = false;

  // Dispenser
  DispenserProfileR? dispenserProfile;
  List<InventoryItemInfo> dispenserStock = [];
  List<DispenseHistoryEntry> dispenserHistory = [];
  List<Prescription> dispenserPendingPrescriptions = [];
  PrescriptionDetail? dispenserPrescriptionDetail;

  int unreadNotificationCount = 0;
  Timer? _notificationTimer;

  Future<void> loadPatient() => _load(() async {
    final profile = await _service.getPatientProfile();
    final doctors = await _service.getPatientDoctors();
    final prescriptions = await _service.getPatientPrescriptions();
    final reports = await _service.getPatientReports();
    final labTests = await _service.getLabTests();
    final onDutyStaff = await _service.getOnDutyStaff();
    final ambulance = await _service.getAmbulanceContacts();
    final notifications = await _service.getPatientNotifications();

    patientProfile = profile;
    patientDoctors = doctors.map(DoctorModel.fromStaffInfo).toList();
    final doctorNameById = <int, String>{
      for (final doctor in patientDoctors)
        if (doctor.userId != null) doctor.userId!: doctor.name,
    };
    try {
      final appointments = await _service.getPatientAppointments();
      patientAppointments = appointments
          .map(
            (item) => AppointmentModel.fromAppointmentRequest(
              item,
              doctorNameById[item.doctorId] ?? 'Doctor #${item.doctorId}',
            ),
          )
          .toList();
    } catch (_) {
      final legacy = await _service.getPatientAppointmentsLegacy();
      patientAppointments = legacy
          .map(AppointmentModel.fromPrescription)
          .toList();
    }
    patientReports = reports;
    patientPrescriptions = prescriptions;
    patientLabTests = labTests;
    patientOnDutyStaff = onDutyStaff;
    patientAmbulanceContacts = ambulance;
    patientNotifications = notifications;
    unreadNotificationCount = notifications.where((n) => !n.isRead).length;
  });

  Future<void> refreshNotifications({
    int limit = 30,
    bool silent = false,
  }) async {
    if (!silent) {
      isLoading = true;
      notifyListeners();
    }
    try {
      final notifications = await _service.getPatientNotifications();
      final counts = await _service.getNotificationCounts();
      patientNotifications = notifications.take(limit).toList();
      unreadNotificationCount =
          (counts['unread'] ??
          patientNotifications.where((n) => !n.isRead).length);
    } catch (e) {
      error = e.toString();
    } finally {
      if (!silent) {
        isLoading = false;
      }
      notifyListeners();
    }
  }

  Future<void> markNotificationAsRead(int notificationId) async {
    try {
      final ok = await _service.markNotificationAsRead(notificationId);
      if (!ok) return;
      patientNotifications = patientNotifications.map((n) {
        if (n.notificationId == notificationId) {
          return NotificationInfo(
            notificationId: n.notificationId,
            userId: n.userId,
            title: n.title,
            message: n.message,
            isRead: true,
            createdAt: n.createdAt,
          );
        }
        return n;
      }).toList();
      unreadNotificationCount = patientNotifications
          .where((n) => !n.isRead)
          .length;
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> markAllNotificationsAsRead() async {
    try {
      final ok = await _service.markAllNotificationsAsRead();
      if (!ok) return;
      patientNotifications = patientNotifications
          .map(
            (n) => NotificationInfo(
              notificationId: n.notificationId,
              userId: n.userId,
              title: n.title,
              message: n.message,
              isRead: true,
              createdAt: n.createdAt,
            ),
          )
          .toList();
      unreadNotificationCount = 0;
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  void startNotificationRealtimeSync({
    Duration interval = const Duration(seconds: 3),
  }) {
    _notificationTimer ??= Timer.periodic(interval, (_) {
      refreshNotifications(silent: true);
    });
    refreshNotifications(silent: true);
  }

  void stopNotificationRealtimeSync() {
    _notificationTimer?.cancel();
    _notificationTimer = null;
  }

  /// Loads only patient profile data.
  ///
  /// This is used by profile screens so they don't fail to render when
  /// unrelated patient endpoints (appointments, reports, etc.) fail.
  Future<void> loadPatientProfileOnly() => _load(() async {
    patientProfile = await _service.getPatientProfile();
  });

  /// Loads profile + clinical document summaries used in patient profile page.
  ///
  /// Keeps the profile page independent from unrelated endpoints while still
  /// showing doctor prescriptions and lab reports.
  Future<void> loadPatientProfileWithClinicalData() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      patientProfile = await _service.getPatientProfile();
    } catch (e) {
      error = e.toString();
    }

    try {
      final appointments = await _service.getPatientAppointments();
      final doctorNameById = <int, String>{
        for (final doctor in patientDoctors)
          if (doctor.userId != null) doctor.userId!: doctor.name,
      };
      patientAppointments = appointments
          .map(
            (item) => AppointmentModel.fromAppointmentRequest(
              item,
              doctorNameById[item.doctorId] ?? 'Doctor #${item.doctorId}',
            ),
          )
          .toList();
    } catch (e) {
      try {
        final legacy = await _service.getPatientAppointmentsLegacy();
        patientAppointments = legacy
            .map(AppointmentModel.fromPrescription)
            .toList();
      } catch (_) {
        error ??= e.toString();
      }
    }

    try {
      patientPrescriptions = await _service.getPatientPrescriptions();
    } catch (e) {
      error ??= e.toString();
    }

    try {
      patientReports = await _service.getPatientReports();
    } catch (e) {
      error ??= e.toString();
    }

    isLoading = false;
    notifyListeners();
  }

  Future<bool> updatePatientProfile({
    required String name,
    required String phone,
    String? bloodGroup,
    DateTime? dateOfBirth,
    String? gender,
    String? profileImageUrl,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final result = await _service.updatePatientProfile(
        name: name,
        phone: phone,
        bloodGroup: bloodGroup,
        dateOfBirth: dateOfBirth,
        gender: gender,
        profileImageUrl: profileImageUrl,
      );

      final normalized = result.trim().toLowerCase();
      if (normalized != 'profile updated successfully') {
        error = result;
        return false;
      }

      final profile = await _service.getPatientProfile();
      patientProfile = profile;
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<PrescriptionDetail?> loadPatientPrescriptionDetails(
    int prescriptionId,
  ) async {
    try {
      return await _service.getPatientPrescriptionDetail(prescriptionId);
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<void> loadDoctor() => _load(() async {
    doctorHome = await _service.getDoctorHome();
    doctorProfile = await _service.getDoctorProfile();
    doctorReports = await _service.getDoctorReports();
    doctorPrescriptionList = await _service.getDoctorPrescriptions();
    try {
      doctorAppointmentRequests = await _service.getDoctorAppointmentRequests(
        limit: 200,
        offset: 0,
      );
    } catch (_) {
      doctorAppointmentRequests = const [];
    }
  });

  Future<void> loadDoctorReports() => _load(() async {
    doctorReports = await _service.getDoctorReports();
  });

  Future<bool> markDoctorReportReviewed(int reportId) async {
    try {
      final ok = await _service.markDoctorReportReviewed(reportId);
      if (ok) {
        doctorReports = doctorReports
            .map((r) => r.reportId == reportId ? r.copyWith(reviewed: true) : r)
            .toList();
        notifyListeners();
      }
      return ok;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> submitDoctorReview({
    required int reportId,
    required String notes,
    required String action,
    required bool visibleToPatient,
  }) async {
    try {
      final ok = await _service.submitDoctorReview(
        reportId: reportId,
        notes: notes,
        action: action,
        visibleToPatient: visibleToPatient,
      );
      if (ok) {
        doctorReports = doctorReports
            .map(
              (r) => r.reportId == reportId
                  ? r.copyWith(
                      reviewed: true,
                      doctorNotes: notes,
                      reviewAction: action,
                      visibleToPatient: visibleToPatient,
                    )
                  : r,
            )
            .toList();
        notifyListeners();
      }
      return ok;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> loadDoctorAppointmentRequests({
    String? status,
    String? query,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      doctorAppointmentRequests = await _service.getDoctorAppointmentRequests(
        status: status,
        query: query,
        limit: 200,
        offset: 0,
      );
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateDoctorAppointmentRequestStatus({
    required int appointmentRequestId,
    required String status,
    String? declineReason,
  }) async {
    try {
      final ok = await _service.updateDoctorAppointmentRequestStatus(
        appointmentRequestId: appointmentRequestId,
        status: status,
        declineReason: declineReason,
      );
      if (ok) {
        await loadDoctorAppointmentRequests();
      }
      return ok;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateDoctorProfile({
    required String name,
    required String email,
    required String phone,
    required String qualification,
    required String designation,
    String? profilePictureUrl,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final ok = await _service.updateDoctorProfile(
        name: name,
        email: email,
        phone: phone,
        qualification: qualification,
        designation: designation,
        profilePictureUrl: profilePictureUrl,
      );
      if (!ok) {
        error = 'Failed to update profile';
        return false;
      }
      doctorProfile = await _service.getDoctorProfile();
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<List<PatientPrescriptionListItem>> searchDoctorPatients({
    required String query,
    int limit = 30,
  }) async {
    try {
      final rows = await _service.getDoctorPrescriptions(
        query: query,
        limit: limit,
      );
      doctorPrescriptionList = rows;
      notifyListeners();
      return rows;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return const [];
    }
  }

  Future<Map<String, String?>> lookupDoctorPatient(String query) async {
    try {
      return await _service.getDoctorPatientByPhoneOrName(query);
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return {'id': null, 'name': null};
    }
  }

  Future<int> saveDoctorPrescription({
    required Prescription prescription,
    required List<PrescribedItem> items,
    required String patientPhone,
  }) async {
    try {
      return await _service.createDoctorPrescription(
        prescription: prescription,
        items: items,
        patientPhone: patientPhone,
      );
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return -1;
    }
  }

  Future<PatientPrescriptionDetails?> loadPrescriptionDetails(
    int prescriptionId,
  ) async {
    try {
      return await _service.getDoctorPrescriptionDetails(prescriptionId);
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<void> loadAdmin() => _load(() async {
    adminOverview = await _service.getAdminOverview();
    adminAnalytics = await _service.getAdminAnalytics();
    adminProfile = await _service.getAdminProfile();
    adminAudits = await _service.getRecentAudit();
    adminUsers = await _service.getAdminUsers();
    adminInventory = await _service.getAdminInventory();
    adminInventoryCategories = await _service.getAdminInventoryCategories();
    adminAmbulanceContacts = await _service.getAdminAmbulanceContacts();
  });

  Future<void> loadAdminInventoryOnly() => _load(() async {
    adminInventory = await _service.getAdminInventory();
    adminInventoryCategories = await _service.getAdminInventoryCategories();
  });

  Future<bool> addAdminInventoryCategory({
    required String name,
    String? description,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final ok = await _service.addAdminInventoryCategory(
        name: name,
        description: description,
      );
      if (!ok) {
        error = 'Failed to add inventory category';
        return false;
      }
      adminInventoryCategories = await _service.getAdminInventoryCategories();
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addAdminInventoryItem({
    required int categoryId,
    required String itemName,
    required String unit,
    required int minimumStock,
    required int initialStock,
    required bool canRestockDispenser,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final ok = await _service.addAdminInventoryItem(
        categoryId: categoryId,
        itemName: itemName,
        unit: unit,
        minimumStock: minimumStock,
        initialStock: initialStock,
        canRestockDispenser: canRestockDispenser,
      );
      if (!ok) {
        error = 'Failed to add inventory item';
        return false;
      }
      adminInventory = await _service.getAdminInventory();
      adminInventoryCategories = await _service.getAdminInventoryCategories();
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateAdminInventoryStock({
    required int itemId,
    required int quantity,
    required String type,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final ok = await _service.updateAdminInventoryStock(
        itemId: itemId,
        quantity: quantity,
        type: type,
      );
      if (!ok) {
        error = 'Failed to update inventory stock';
        return false;
      }
      adminInventory = await _service.getAdminInventory();
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateAdminDispenserRestockFlag({
    required int itemId,
    required bool canRestock,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final ok = await _service.updateAdminDispenserRestockFlag(
        itemId: itemId,
        canRestock: canRestock,
      );
      if (!ok) {
        error = 'Failed to update restock permission';
        return false;
      }
      adminInventory = await _service.getAdminInventory();
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateAdminMinimumThreshold({
    required int itemId,
    required int newThreshold,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final ok = await _service.updateAdminMinimumThreshold(
        itemId: itemId,
        newThreshold: newThreshold,
      );
      if (!ok) {
        error = 'Failed to update minimum threshold';
        return false;
      }
      adminInventory = await _service.getAdminInventory();
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadAdminUsersOnly({String role = 'ALL'}) => _load(() async {
    adminUsers = await _service.getAdminUsers(role: role);
  });

  Future<void> loadAdminRostersForDate(DateTime date) => _load(() async {
    final day = DateTime(date.year, date.month, date.day);
    adminRosterStaff = await _service.getAdminStaffList(limit: 300);
    adminRosters = await _service.getAdminRosters(
      fromDate: day,
      toDate: day,
      includeDeleted: false,
    );
  });

  Future<bool> saveAdminRosterAssignment({
    String rosterId = '',
    required String staffId,
    required String shiftType,
    required DateTime shiftDate,
    String timeRange = '',
    String status = 'ACTIVE',
    String? approvedBy,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final ok = await _service.saveAdminRoster(
        rosterId: rosterId,
        staffId: staffId,
        shiftType: shiftType,
        shiftDate: shiftDate,
        timeRange: timeRange,
        status: status,
        approvedBy: approvedBy,
      );
      if (!ok) {
        error = 'Failed to save roster assignment';
        return false;
      }
      final day = DateTime(shiftDate.year, shiftDate.month, shiftDate.day);
      adminRosters = await _service.getAdminRosters(
        fromDate: day,
        toDate: day,
        includeDeleted: false,
      );
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteAdminRosterAssignment(
    int rosterId,
    DateTime shiftDate,
  ) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final ok = await _service.deleteAdminRoster(rosterId);
      if (!ok) {
        error = 'Failed to delete roster assignment';
        return false;
      }
      final day = DateTime(shiftDate.year, shiftDate.month, shiftDate.day);
      adminRosters = await _service.getAdminRosters(
        fromDate: day,
        toDate: day,
        includeDeleted: false,
      );
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createAdminUserWithPassword({
    required String name,
    required String email,
    required String password,
    required String role,
    String? phone,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final res = await _service.createAdminUserWithPassword(
        name: name,
        email: email,
        password: password,
        role: role,
        phone: phone,
      );
      final createdId = int.tryParse(res.trim());
      final ok = createdId != null && createdId > 0;
      if (!ok) {
        error = res;
        return false;
      }
      adminUsers = await _service.getAdminUsers();
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> toggleAdminUserActive(String userId) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final ok = await _service.toggleAdminUserActive(userId);
      if (!ok) {
        error = 'Failed to update user status';
        return false;
      }
      adminUsers = await _service.getAdminUsers();
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadAdminAmbulanceContacts() => _load(() async {
    adminAmbulanceContacts = await _service.getAdminAmbulanceContacts();
  });

  Future<bool> addAdminAmbulanceContact({
    required String title,
    required String phoneBn,
    required String phoneEn,
    required bool isPrimary,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final ok = await _service.addAdminAmbulanceContact(
        title: title,
        phoneBn: phoneBn,
        phoneEn: phoneEn,
        isPrimary: isPrimary,
      );
      if (!ok) {
        error = 'Failed to add ambulance contact';
        return false;
      }
      adminAmbulanceContacts = await _service.getAdminAmbulanceContacts();
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateAdminAmbulanceContact({
    required int id,
    required String title,
    required String phoneBn,
    required String phoneEn,
    required bool isPrimary,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final ok = await _service.updateAdminAmbulanceContact(
        id: id,
        title: title,
        phoneBn: phoneBn,
        phoneEn: phoneEn,
        isPrimary: isPrimary,
      );
      if (!ok) {
        error = 'Failed to update ambulance contact';
        return false;
      }
      adminAmbulanceContacts = await _service.getAdminAmbulanceContacts();
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateAdminProfile({
    required String name,
    required String phone,
    String? designation,
    String? qualification,
    String? profilePictureUrl,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final res = await _service.updateAdminProfile(
        name: name,
        phone: phone,
        designation: designation,
        qualification: qualification,
        profilePictureUrl: profilePictureUrl,
      );
      final ok = res.trim().toUpperCase() == 'OK';
      if (!ok) {
        error = res;
        return false;
      }
      adminProfile = await _service.getAdminProfile();
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadLab() => _load(() async {
    labSummary = await _service.getLabSummary();
    labHistory = await _service.getLabHistory();
    labResults = await _service.getAllLabResults();
    labAvailableTests = await _service.getAllLabTests();
    labProfile = await _service.getLabStaffProfile();
  });

  Future<bool> updateLabStaffProfile({
    required String name,
    required String email,
    required String phone,
    required String qualification,
    required String designation,
    String? profilePictureUrl,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final ok = await _service.updateLabStaffProfile(
        name: name,
        email: email,
        phone: phone,
        qualification: qualification,
        designation: designation,
        profilePictureUrl: profilePictureUrl,
      );
      if (!ok) {
        error = 'Failed to update profile';
        return false;
      }
      labProfile = await _service.getLabStaffProfile();
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> changeMyPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final res = await _service.changeMyPassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      final normalized = res.toLowerCase();
      if (normalized.contains('success')) {
        return true;
      }
      error = res;
      notifyListeners();
      return false;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> loadLabAnalyticsSnapshot({
    DateTime? fromDate,
    DateTime? toDateExclusive,
    String patientType = 'ALL',
  }) async {
    isLabAnalyticsLoading = true;
    error = null;
    notifyListeners();
    try {
      labAnalyticsSnapshot = await _service.getLabAnalyticsSnapshot(
        fromDate: fromDate,
        toDateExclusive: toDateExclusive,
        patientType: patientType,
      );
    } catch (e) {
      error = e.toString();
    } finally {
      isLabAnalyticsLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadDispenser() => _load(() async {
    dispenserProfile = await _service.getDispenserProfile();
    dispenserStock = await _service.getDispenserStock();
    dispenserHistory = await _service.getDispenserHistory();
    dispenserPendingPrescriptions = await _service
        .getDispenserPendingPrescriptions();
  });

  Future<void> loadDispenserPendingOnly() => _load(() async {
    dispenserPendingPrescriptions = await _service
        .getDispenserPendingPrescriptions();
  });

  Future<PrescriptionDetail?> loadDispenserPrescriptionDetail(
    int prescriptionId,
  ) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      dispenserPrescriptionDetail = await _service
          .getDispenserPrescriptionDetail(prescriptionId);
      return dispenserPrescriptionDetail;
    } catch (e) {
      error = e.toString();
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<List<InventoryItemInfo>> searchDispenserInventoryItems(
    String query,
  ) async {
    try {
      return await _service.searchDispenserInventoryItems(query);
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return const [];
    }
  }

  Future<bool> dispenseDispenserPrescription({
    required int prescriptionId,
    required List<DispenseItemRequest> items,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final ok = await _service.dispensePrescription(
        prescriptionId: prescriptionId,
        dispenserId: 0,
        items: items,
      );
      if (!ok) {
        error = 'Dispense request failed';
        return false;
      }
      dispenserPendingPrescriptions = await _service
          .getDispenserPendingPrescriptions();
      dispenserStock = await _service.getDispenserStock();
      dispenserHistory = await _service.getDispenserHistory();
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateDispenserProfile({
    required String name,
    required String phone,
    required String qualification,
    required String designation,
    String? profilePictureUrl,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final res = await _service.updateDispenserProfile(
        name: name,
        phone: phone,
        qualification: qualification,
        designation: designation,
        profilePictureUrl: profilePictureUrl,
      );
      final normalized = res.trim().toLowerCase();
      final ok = normalized == 'ok' || normalized.contains('success');
      if (!ok) {
        error = res;
        return false;
      }
      dispenserProfile = await _service.getDispenserProfile();
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _load(Future<void> Function() action) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await action();
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    stopNotificationRealtimeSync();
    super.dispose();
  }
}
