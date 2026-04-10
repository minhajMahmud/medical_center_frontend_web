import 'package:backend_client/backend_client.dart';

import 'api_service.dart';

class AuthService {
  final _client = ApiService.instance.client;
  final _keyManager = ApiService.instance.authKeyManager;

  Future<LoginResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.login(email, password);
    if (response.success && (response.token?.isNotEmpty ?? false)) {
      await _keyManager.put(response.token!);
    }
    return response;
  }

  Future<LoginResponse> verifyLoginOtp({
    required String email,
    required String otp,
    required String otpToken,
  }) async {
    final response = await _client.auth.verifyLoginOtp(email, otp, otpToken);
    if (response.success && (response.token?.isNotEmpty ?? false)) {
      await _keyManager.put(response.token!);
    }
    return response;
  }

  Future<OtpChallengeResponse> startSignupPhoneOtp({
    required String email,
    required String phone,
  }) => _client.auth.startSignupPhoneOtp(email, phone);

  Future<LoginResponse> completeSignupWithPhoneOtp({
    required String email,
    required String phone,
    required String phoneOtp,
    required String phoneOtpToken,
    required String password,
    required String name,
    required String role,
    String? bloodGroup,
    DateTime? dateOfBirth,
    String? gender,
  }) async {
    final response = await _client.auth.completeSignupWithPhoneOtp(
      email,
      phone,
      phoneOtp,
      phoneOtpToken,
      password,
      name,
      role,
      bloodGroup,
      dateOfBirth,
      gender,
    );
    if (response.success && (response.token?.isNotEmpty ?? false)) {
      await _keyManager.put(response.token!);
    }
    return response;
  }

  Future<String> requestPasswordReset({required String email}) {
    return _client.auth.requestPasswordReset(email);
  }

  Future<String> verifyPasswordReset({
    required String email,
    required String otp,
    required String token,
  }) {
    return _client.auth.verifyPasswordReset(email, otp, token);
  }

  Future<String> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) {
    return _client.auth.resetPassword(email, token, newPassword);
  }

  Future<void> logout() async {
    await _client.auth.logout();
    await _keyManager.remove();
  }

  Future<String?> getCurrentRole() async {
    try {
      return await _client.patient.getUserRole();
    } catch (_) {
      return null;
    }
  }
}
