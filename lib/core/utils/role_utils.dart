enum AppRole { patient, doctor, admin, lab, dispenser, unknown }

class RoleUtils {
  static AppRole parse(String? role) {
    final v = role?.trim().toUpperCase();
    final normalized = (v ?? '').replaceAll(RegExp(r'[^A-Z0-9]'), '');

    switch (normalized) {
      case 'STUDENT':
      case 'TEACHER':
      case 'STAFF':
      case 'OUTSIDE':
      case 'PATIENT':
        return AppRole.patient;
      case 'DOCTOR':
        return AppRole.doctor;
      case 'ADMIN':
        return AppRole.admin;
      case 'LAB':
      case 'LABSTAFF':
      case 'LABSTAFFER':
      case 'LABTEAM':
      case 'LABTEST':
      case 'LAB_TESTER':
      case 'LABTESTER':
      case 'LABTECH':
      case 'LABTECHNICIAN':
      case 'LABORATORY':
        return AppRole.lab;
      case 'DISPENSER':
        return AppRole.dispenser;
      default:
        if (normalized.contains('LAB')) return AppRole.lab;
        if (normalized.contains('DISPENS')) return AppRole.dispenser;
        if (normalized.contains('DOCTOR')) return AppRole.doctor;
        if (normalized.contains('ADMIN')) return AppRole.admin;
        if (normalized.contains('PATIENT') ||
            normalized.contains('STUDENT') ||
            normalized.contains('TEACHER') ||
            normalized.contains('STAFF')) {
          return AppRole.patient;
        }

        return AppRole.unknown;
    }
  }

  static String dashboardPathForRole(AppRole role) {
    switch (role) {
      case AppRole.patient:
        return '/patient/dashboard';
      case AppRole.doctor:
        return '/doctor/dashboard';
      case AppRole.admin:
        return '/admin/dashboard';
      case AppRole.lab:
        return '/lab/dashboard';
      case AppRole.dispenser:
        return '/dispenser/dashboard';
      case AppRole.unknown:
        return '/home';
    }
  }
}
