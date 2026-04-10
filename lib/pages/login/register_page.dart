import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../core/utils/role_utils.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _otp = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  String _role = 'STUDENT';
  String _bloodGroup = 'A+';
  String _gender = 'Male';
  DateTime? _dob;
  bool _acceptedTerms = false;
  bool _otpRequested = false;
  bool _obscurePass = true;
  bool _obscureConfirmPass = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(1940),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _dob = picked);
    }
  }

  Future<void> _requestOtp(AuthController auth) async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept Terms and Privacy Policy.'),
        ),
      );
      return;
    }

    final ok = await auth.requestSignupOtp(
      email: _email.text.trim(),
      phone: _phone.text.trim(),
    );

    if (!mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Could not send OTP.')),
      );
      return;
    }

    setState(() => _otpRequested = true);
    if ((auth.signupDebugOtp?.isNotEmpty ?? false)) {
      _otp.text = auth.signupDebugOtp!;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('OTP sent. Please verify to complete registration.'),
      ),
    );
  }

  Future<void> _completeRegistration(AuthController auth) async {
    if (!_formKey.currentState!.validate()) return;
    if (_otp.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the OTP code.')),
      );
      return;
    }

    final ok = await auth.completeSignup(
      name: _name.text.trim(),
      email: _email.text.trim(),
      phone: _phone.text.trim(),
      password: _password.text,
      otp: _otp.text.trim(),
      role: _role,
      bloodGroup: _bloodGroup,
      dateOfBirth: _dob,
      gender: _gender,
    );

    if (!mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Registration failed.')),
      );
      return;
    }

    context.go(RoleUtils.dashboardPathForRole(auth.appRole));
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
                  const Text('Already have an account?'),
                  const SizedBox(width: 10),
                  FilledButton.tonal(
                    onPressed: () => context.go('/login'),
                    child: const Text('Log In'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFDDE8F5), Color(0xFFC8D7EA)],
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 280,
                            height: 280,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 18,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.medical_services_outlined,
                              size: 120,
                              color: Color(0xFF1976D2),
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            'Dedicated to Your Health\n& Wellness',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Join the NSTU healthcare community today. Access online appointments, medical history, and emergency support.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(32),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Create Patient Account',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Please fill in your details using your valid credentials.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _name,
                                    decoration: const InputDecoration(
                                      labelText: 'Full Name',
                                    ),
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                        ? 'Enter your full name'
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _email,
                                    decoration: const InputDecoration(
                                      labelText: 'Email Address',
                                    ),
                                    validator: (v) {
                                      final value = v?.trim() ?? '';
                                      if (value.isEmpty) {
                                        return 'Enter email';
                                      }
                                      if (!value.contains('@')) {
                                        return 'Invalid email';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _phone,
                                    decoration: const InputDecoration(
                                      labelText: 'Phone Number',
                                    ),
                                    validator: (v) =>
                                        (v == null || v.trim().length < 10)
                                        ? 'Enter valid phone'
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _role,
                                    decoration: const InputDecoration(
                                      labelText: 'User Role',
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'STUDENT',
                                        child: Text('Student'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'TEACHER',
                                        child: Text('Teacher'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'STAFF',
                                        child: Text('Staff'),
                                      ),
                                    ],
                                    onChanged: (v) {
                                      if (v != null) {
                                        setState(() => _role = v);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _bloodGroup,
                                    decoration: const InputDecoration(
                                      labelText: 'Blood Group',
                                    ),
                                    items:
                                        const [
                                              'A+',
                                              'A-',
                                              'B+',
                                              'B-',
                                              'AB+',
                                              'AB-',
                                              'O+',
                                              'O-',
                                            ]
                                            .map(
                                              (g) => DropdownMenuItem(
                                                value: g,
                                                child: Text(g),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: (v) {
                                      if (v != null) {
                                        setState(() => _bloodGroup = v);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: InkWell(
                                    onTap: _pickDob,
                                    child: InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: 'Date of Birth',
                                        suffixIcon: Icon(Icons.calendar_today),
                                      ),
                                      child: Text(
                                        _dob == null
                                            ? 'mm/dd/yyyy'
                                            : '${_dob!.month.toString().padLeft(2, '0')}/${_dob!.day.toString().padLeft(2, '0')}/${_dob!.year}',
                                        style: TextStyle(
                                          color: _dob == null
                                              ? const Color(0xFF94A3B8)
                                              : null,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Gender',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 16,
                              children: [
                                _GenderChoice(
                                  label: 'Male',
                                  selected: _gender == 'Male',
                                  onTap: () => setState(() => _gender = 'Male'),
                                ),
                                _GenderChoice(
                                  label: 'Female',
                                  selected: _gender == 'Female',
                                  onTap: () =>
                                      setState(() => _gender = 'Female'),
                                ),
                                _GenderChoice(
                                  label: 'Other',
                                  selected: _gender == 'Other',
                                  onTap: () =>
                                      setState(() => _gender = 'Other'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _password,
                                    obscureText: _obscurePass,
                                    decoration: InputDecoration(
                                      labelText: 'Password',
                                      suffixIcon: IconButton(
                                        onPressed: () => setState(() {
                                          _obscurePass = !_obscurePass;
                                        }),
                                        icon: Icon(
                                          _obscurePass
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                        ),
                                      ),
                                    ),
                                    validator: (v) {
                                      final value = v ?? '';
                                      if (value.length < 6) {
                                        return 'At least 6 characters';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _confirmPassword,
                                    obscureText: _obscureConfirmPass,
                                    decoration: InputDecoration(
                                      labelText: 'Confirm Password',
                                      suffixIcon: IconButton(
                                        onPressed: () => setState(() {
                                          _obscureConfirmPass =
                                              !_obscureConfirmPass;
                                        }),
                                        icon: Icon(
                                          _obscureConfirmPass
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                        ),
                                      ),
                                    ),
                                    validator: (v) {
                                      if (v != _password.text) {
                                        return 'Passwords do not match';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_otpRequested)
                              TextFormField(
                                controller: _otp,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'OTP Code',
                                  helperText:
                                      'Enter the OTP sent to your phone/email.',
                                ),
                                validator: (v) {
                                  if (_otpRequested &&
                                      (v == null || v.trim().isEmpty)) {
                                    return 'Enter OTP';
                                  }
                                  return null;
                                },
                              ),
                            const SizedBox(height: 10),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _acceptedTerms,
                              onChanged: (v) =>
                                  setState(() => _acceptedTerms = v ?? false),
                              title: const Text(
                                'I agree to the Terms of Service and Privacy Policy.',
                              ),
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: auth.isLoading
                                        ? null
                                        : () => _requestOtp(auth),
                                    child: auth.isLoading && !_otpRequested
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text('Send OTP'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: auth.isLoading
                                        ? null
                                        : _otpRequested
                                        ? () => _completeRegistration(auth)
                                        : null,
                                    child: auth.isLoading && _otpRequested
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text('Complete Registration'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenderChoice extends StatelessWidget {
  const _GenderChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            selected
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            size: 18,
            color: selected ? const Color(0xFF1976D2) : const Color(0xFF94A3B8),
          ),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}
