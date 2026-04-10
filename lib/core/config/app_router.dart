import 'package:go_router/go_router.dart';

import '../../controllers/auth_controller.dart';
import '../../core/utils/role_utils.dart';
import '../../pages/admin/admin_inventory_page.dart';
import '../../pages/admin/admin_ambulance_page.dart';
import '../../pages/admin/admin_page.dart';
import '../../pages/admin/admin_reports_page.dart';
import '../../pages/admin/admin_staff_roster_page.dart';
import '../../pages/admin/admin_users_page.dart';
import '../../pages/appointments/appointments_page.dart';
import '../../pages/dashboard/patient_dashboard_page.dart';
import '../../pages/dispenser/dispenser_dashboard_page.dart';
import '../../pages/dispenser/dispenser_history_page.dart';
import '../../pages/dispenser/dispenser_profile_page.dart';
import '../../pages/dispenser/dispenser_stock_page.dart';
import '../../pages/doctor/doctor_dashboard_page.dart';
import '../../pages/doctor/doctor_prescription_creator_page.dart';
import '../../pages/doctor/doctor_profile_page.dart';
import '../../pages/doctor/doctor_prescriptions_page.dart';
import '../../pages/doctor/doctor_records_page.dart';
import '../../pages/doctor/doctor_reports_page.dart';
import '../../pages/home/landing_page.dart';
import '../../pages/lab/lab_dashboard_page.dart';
import '../../pages/lab/lab_manage_test_page.dart';
import '../../pages/lab/lab_payments_page.dart';
import '../../pages/lab/lab_profile_page.dart';
import '../../pages/lab/lab_analytics_page.dart';
import '../../pages/lab/lab_results_page.dart';
import '../../pages/lab/lab_settings_page.dart';
import '../../pages/lab/lab_support_page.dart';
import '../../pages/lab/lab_announcements_page.dart';
import '../../pages/lab/lab_upload_page.dart';
import '../../pages/login/login_page.dart';
import '../../pages/login/forgot_password_page.dart';
import '../../pages/login/register_page.dart';
import '../../pages/patient/patient_lab_tests_page.dart';
import '../../pages/patient/patient_payments_page.dart';
import '../../pages/patient/patient_profile_page.dart';
import '../../pages/patient/patient_staff_info_page.dart';
import '../../pages/reports/medical_reports_page.dart';

GoRouter createAppRouter(AuthController auth) {
  bool canAccess(AppRole role, String path) {
    if (path.startsWith('/patient')) return role == AppRole.patient;
    if (path.startsWith('/doctor')) return role == AppRole.doctor;
    if (path.startsWith('/admin')) return role == AppRole.admin;
    if (path.startsWith('/lab')) return role == AppRole.lab;
    if (path.startsWith('/dispenser')) return role == AppRole.dispenser;
    return true;
  }

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: auth,
    redirect: (_, state) {
      final path = state.uri.path;
      final loggedIn = auth.isAuthenticated;
      final role = auth.appRole;

      if (path == '/') {
        return loggedIn ? RoleUtils.dashboardPathForRole(role) : '/login';
      }

      final tryingPrivate =
          path.startsWith('/patient') ||
          path.startsWith('/doctor') ||
          path.startsWith('/admin') ||
          path.startsWith('/lab') ||
          path.startsWith('/dispenser');

      if (!loggedIn && tryingPrivate) return '/login';

      if (loggedIn && path == '/login') {
        return RoleUtils.dashboardPathForRole(role);
      }

      if (loggedIn && path == '/register') {
        return RoleUtils.dashboardPathForRole(role);
      }

      if (loggedIn && path == '/dashboard') {
        return RoleUtils.dashboardPathForRole(role);
      }

      if (loggedIn && tryingPrivate && !canAccess(role, path)) {
        return RoleUtils.dashboardPathForRole(role);
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/home', builder: (_, __) => const LandingPage()),
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(
        path: '/forgot-password',
        builder: (_, __) => const ForgotPasswordPage(),
      ),
      GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),
      GoRoute(path: '/dashboard', builder: (_, __) => const LandingPage()),

      GoRoute(
        path: '/patient/dashboard',
        builder: (_, __) => const PatientDashboardPage(),
      ),
      GoRoute(
        path: '/patient/doctors',
        redirect: (_, __) => '/patient/dashboard',
      ),
      GoRoute(
        path: '/patient/appointments',
        builder: (_, __) => const AppointmentsPage(),
      ),
      GoRoute(
        path: '/patient/reports',
        builder: (_, __) => const MedicalReportsPage(),
      ),
      GoRoute(
        path: '/patient/profile',
        builder: (_, __) => const PatientProfilePage(),
      ),
      GoRoute(
        path: '/patient/lab-tests',
        builder: (_, __) => const PatientLabTestsPage(),
      ),
      GoRoute(
        path: '/patient/payments',
        builder: (_, __) => const PatientPaymentsPage(),
      ),
      GoRoute(
        path: '/patient/staff',
        builder: (_, __) => const PatientStaffInfoPage(),
      ),

      GoRoute(
        path: '/doctor/dashboard',
        builder: (_, __) => const DoctorDashboardPage(),
      ),
      GoRoute(
        path: '/doctor/patients',
        builder: (_, __) => const DoctorRecordsPage(),
      ),
      GoRoute(
        path: '/doctor/appointments',
        builder: (_, __) => const DoctorPrescriptionsPage(),
      ),
      GoRoute(
        path: '/doctor/reports',
        builder: (_, __) => const DoctorReportsPage(),
      ),
      GoRoute(
        path: '/doctor/profile',
        builder: (_, __) => const DoctorProfilePage(),
      ),
      GoRoute(
        path: '/doctor/prescriptions',
        builder: (_, __) => const DoctorPrescriptionsPage(),
      ),
      GoRoute(
        path: '/doctor/prescriptions/create',
        builder: (_, state) => DoctorPrescriptionCreatorPage(
          patientId: state.uri.queryParameters['patientId'],
          prescriptionId: int.tryParse(
            state.uri.queryParameters['prescriptionId'] ?? '',
          ),
          patientName: state.uri.queryParameters['name'],
          phone: state.uri.queryParameters['phone'],
          age: state.uri.queryParameters['age'],
          gender: state.uri.queryParameters['gender'],
          isNewRecord: state.uri.queryParameters['new'] == '1',
        ),
      ),
      GoRoute(
        path: '/doctor/records',
        builder: (_, __) => const DoctorRecordsPage(),
      ),

      GoRoute(path: '/admin/dashboard', builder: (_, __) => const AdminPage()),
      GoRoute(path: '/admin/users', builder: (_, __) => const AdminUsersPage()),
      GoRoute(
        path: '/admin/roster',
        builder: (_, __) => const AdminStaffRosterPage(),
      ),
      GoRoute(
        path: '/admin/inventory',
        builder: (_, __) => const AdminInventoryPage(),
      ),
      GoRoute(
        path: '/admin/reports',
        builder: (_, __) => const AdminReportsPage(),
      ),
      GoRoute(
        path: '/admin/ambulance',
        builder: (_, __) => const AdminAmbulancePage(),
      ),

      GoRoute(
        path: '/lab/dashboard',
        builder: (_, __) => const LabDashboardPage(),
      ),
      GoRoute(
        path: '/lab/payments',
        builder: (_, __) => const LabPaymentsPage(),
      ),
      GoRoute(path: '/lab/upload', builder: (_, __) => const LabUploadPage()),
      GoRoute(
        path: '/lab/manage-test',
        builder: (_, __) => const LabManageTestPage(),
      ),
      GoRoute(path: '/lab/profile', builder: (_, __) => const LabProfilePage()),
      GoRoute(
        path: '/lab/analytics',
        builder: (_, __) => const LabAnalyticsPage(),
      ),
      GoRoute(
        path: '/lab/settings',
        builder: (_, __) => const LabSettingsPage(),
      ),
      GoRoute(path: '/lab/support', builder: (_, __) => const LabSupportPage()),
      GoRoute(
        path: '/lab/announcements',
        builder: (_, __) => const LabAnnouncementsPage(),
      ),
      GoRoute(path: '/lab/results', builder: (_, __) => const LabResultsPage()),

      GoRoute(
        path: '/dispenser/dashboard',
        builder: (_, __) => const DispenserDashboardPage(),
      ),
      GoRoute(
        path: '/dispenser/stock',
        builder: (_, __) => const DispenserStockPage(),
      ),
      GoRoute(
        path: '/dispenser/history',
        builder: (_, __) => const DispenserHistoryPage(),
      ),
      GoRoute(
        path: '/dispenser/profile',
        builder: (_, __) => const DispenserProfilePage(),
      ),
    ],
  );
}
