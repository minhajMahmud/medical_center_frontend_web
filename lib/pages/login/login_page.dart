import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../core/utils/role_utils.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _otp = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _submitLogin(AuthController auth) async {
    final ok = await auth.login(
      email: _email.text.trim(),
      password: _password.text,
    );

    if (!mounted) return;

    if (ok) {
      context.go(RoleUtils.dashboardPathForRole(auth.appRole));
      return;
    }

    if (auth.requiresEmailOtp) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('We sent an OTP to your email. Please verify.'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(auth.error ?? 'Operation failed')));
  }

  Future<void> _submitOtp(AuthController auth) async {
    final ok = await auth.verifyLoginOtp(_otp.text.trim());
    if (!mounted) return;

    if (ok) {
      context.go(RoleUtils.dashboardPathForRole(auth.appRole));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(auth.error ?? 'OTP verification failed')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        color: const Color(0xFFF1F5F9),
        child: Column(
          children: [
            Container(
              height: 72,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 16,
                    backgroundColor: Color(0xFF1976D2),
                    child: Icon(
                      Icons.local_hospital,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'NSTU Medical Center',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => context.go('/register'),
                    child: const Text('Create account'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Icon(
                            Icons.local_hospital,
                            color: Color(0xFF1976D2),
                            size: 40,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Welcome Back',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            auth.requiresEmailOtp
                                ? 'Enter the OTP sent to your email to continue.'
                                : 'Securely log in to access your medical records and appointments.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 22),
                          TextField(
                            controller: _email,
                            enabled: !auth.requiresEmailOtp,
                            decoration: const InputDecoration(
                              labelText: 'Email Address',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (!auth.requiresEmailOtp)
                            TextField(
                              controller: _password,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  onPressed: () => setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  }),
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                            ),
                          if (!auth.requiresEmailOtp)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: auth.isLoading
                                    ? null
                                    : () => context.go('/forgot-password'),
                                child: const Text('Forgot Password?'),
                              ),
                            ),
                          if (auth.requiresEmailOtp)
                            TextField(
                              controller: _otp,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Email OTP',
                                prefixIcon: Icon(Icons.password_outlined),
                              ),
                            ),
                          const SizedBox(height: 18),
                          SizedBox(
                            height: 48,
                            child: FilledButton(
                              onPressed: auth.isLoading
                                  ? null
                                  : () => auth.requiresEmailOtp
                                        ? _submitOtp(auth)
                                        : _submitLogin(auth),
                              child: auth.isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      auth.requiresEmailOtp
                                          ? 'Verify OTP'
                                          : 'Log In to Portal',
                                    ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (auth.requiresEmailOtp)
                            TextButton(
                              onPressed: auth.isLoading
                                  ? null
                                  : () {
                                      auth.clearAuthMessages();
                                      _otp.clear();
                                    },
                              child: const Text('Use another login instead'),
                            )
                          else
                            TextButton(
                              onPressed: auth.isLoading
                                  ? null
                                  : () => context.go('/register'),
                              child: const Text(
                                'New patient? Create an account',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
