import 'package:flutter/foundation.dart';
import 'package:backend_client/backend_client.dart';

import '../core/config/app_config.dart';
import '../core/utils/role_utils.dart';
import '../services/auth_service.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._authService);

  final AuthService _authService;

  bool isLoading = false;
  bool isAuthenticated = false;
  String? role;
  AppRole appRole = AppRole.unknown;
  String? error;
  bool requiresEmailOtp = false;
  String? pendingLoginEmail;
  String? pendingLoginOtpToken;

  String? signupOtpToken;
  String? signupDebugOtp;
  String? signupEmail;
  String? signupPhone;

  String _connectionHelpMessage([String? action]) {
    final operation = (action == null || action.isEmpty) ? 'request' : action;
    return 'Could not connect to server while $operation. '
        'API: ${AppConfig.apiBaseUrl} '
        'Please ensure backend is running on http://localhost:8080 (for local dev).';
  }

  String _withResendHint(String baseMessage) {
    final m = baseMessage.toLowerCase();
    final looksLikeResendOtpIssue =
        m.contains('otp') &&
        (m.contains('failed to send') ||
            m.contains('resend') ||
            m.contains('email'));

    if (!looksLikeResendOtpIssue) return baseMessage;

    return '$baseMessage\nHint: check backend RESEND_API_KEY configuration and restart the backend.';
  }

  void clearAuthMessages() {
    error = null;
    requiresEmailOtp = false;
    pendingLoginEmail = null;
    pendingLoginOtpToken = null;
    notifyListeners();
  }

  Future<void> _applyLoginResponse(LoginResponse res) async {
    isAuthenticated = true;
    role = res.role;
    appRole = RoleUtils.parse(res.role);

    if (appRole == AppRole.unknown) {
      try {
        final existingRole = await _authService.getCurrentRole();
        if (existingRole != null && existingRole.isNotEmpty) {
          role = existingRole;
          appRole = RoleUtils.parse(existingRole);
        }
      } catch (_) {
        // Keep current state and allow UI to continue gracefully.
      }
    }

    requiresEmailOtp = false;
    pendingLoginEmail = null;
    pendingLoginOtpToken = null;
  }

  Future<void> bootstrap() async {
    isLoading = true;
    notifyListeners();
    try {
      final existingRole = await _authService.getCurrentRole();
      if (existingRole != null && existingRole.isNotEmpty) {
        role = existingRole;
        appRole = RoleUtils.parse(existingRole);
        isAuthenticated = appRole != AppRole.unknown;
      }
    } catch (_) {
      // Do not override an already authenticated state (race-safe).
      if (!isAuthenticated) {
        role = null;
        appRole = AppRole.unknown;
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login({required String email, required String password}) async {
    isLoading = true;
    error = null;
    requiresEmailOtp = false;
    pendingLoginEmail = null;
    pendingLoginOtpToken = null;
    notifyListeners();

    try {
      final res = await _authService.login(email: email, password: password);
      if (!res.success) {
        error = _withResendHint(res.error ?? 'Login failed');
        return false;
      }

      if (res.requiresEmailOtp == true && (res.otpToken?.isNotEmpty ?? false)) {
        requiresEmailOtp = true;
        pendingLoginEmail = email;
        pendingLoginOtpToken = res.otpToken;
        return false;
      }

      await _applyLoginResponse(res);
      return true;
    } catch (_) {
      error = _connectionHelpMessage('logging in');
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> verifyLoginOtp(String otp) async {
    final email = pendingLoginEmail;
    final token = pendingLoginOtpToken;
    if (email == null || token == null) {
      error = 'OTP session expired. Please login again.';
      notifyListeners();
      return false;
    }

    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final res = await _authService.verifyLoginOtp(
        email: email,
        otp: otp.trim(),
        otpToken: token,
      );
      if (!res.success) {
        error = _withResendHint(res.error ?? 'OTP verification failed');
        return false;
      }
      await _applyLoginResponse(res);
      return true;
    } catch (_) {
      error = _connectionHelpMessage('verifying OTP');
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> requestSignupOtp({
    required String email,
    required String phone,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final challenge = await _authService.startSignupPhoneOtp(
        email: email,
        phone: phone,
      );
      if (!challenge.success || (challenge.token?.isEmpty ?? true)) {
        error = _withResendHint(challenge.error ?? 'Failed to send OTP');
        return false;
      }

      signupEmail = email;
      signupPhone = phone;
      signupOtpToken = challenge.token;
      signupDebugOtp = challenge.debugOtp;
      return true;
    } catch (_) {
      error = _connectionHelpMessage('requesting signup OTP');
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> completeSignup({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String otp,
    required String role,
    String? bloodGroup,
    DateTime? dateOfBirth,
    String? gender,
  }) async {
    if (signupOtpToken == null ||
        signupEmail != email ||
        signupPhone != phone) {
      error = 'Please request OTP first.';
      notifyListeners();
      return false;
    }

    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final res = await _authService.completeSignupWithPhoneOtp(
        email: email,
        phone: phone,
        phoneOtp: otp,
        phoneOtpToken: signupOtpToken!,
        password: password,
        name: name,
        role: role,
        bloodGroup: bloodGroup,
        dateOfBirth: dateOfBirth,
        gender: gender,
      );

      if (!res.success) {
        error = _withResendHint(res.error ?? 'Registration failed');
        return false;
      }

      await _applyLoginResponse(res);
      signupOtpToken = null;
      signupDebugOtp = null;
      signupEmail = null;
      signupPhone = null;
      return true;
    } catch (_) {
      error = _connectionHelpMessage('completing registration');
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> requestPasswordReset(String email) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final result = await _authService.requestPasswordReset(email: email);
      if (!result.contains('.')) {
        error = _withResendHint(result);
        return null;
      }
      return result;
    } catch (_) {
      error = _connectionHelpMessage('requesting password reset');
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> verifyPasswordReset({
    required String email,
    required String otp,
    required String token,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final result = await _authService.verifyPasswordReset(
        email: email,
        otp: otp,
        token: token,
      );
      if (result != 'OK') {
        error = _withResendHint(result);
        return false;
      }
      return true;
    } catch (_) {
      error = _connectionHelpMessage('verifying reset OTP');
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final result = await _authService.resetPassword(
        email: email,
        token: token,
        newPassword: newPassword,
      );
      if (result.toLowerCase().contains('successful')) {
        return true;
      }
      error = _withResendHint(result);
      return false;
    } catch (_) {
      error = _connectionHelpMessage('resetting password');
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    isAuthenticated = false;
    role = null;
    appRole = AppRole.unknown;
    notifyListeners();
  }
}
