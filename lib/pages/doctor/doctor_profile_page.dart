import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/role_dashboard_controller.dart';
import '../../utils/cloudinary_upload.dart';
import '../../widgets/common/change_password_dialog.dart';
import '../../widgets/common/dashboard_shell.dart';

class DoctorProfilePage extends StatefulWidget {
  const DoctorProfilePage({super.key});

  @override
  State<DoctorProfilePage> createState() => _DoctorProfilePageState();
}

class _DoctorProfilePageState extends State<DoctorProfilePage> {
  static const _primaryBlue = Color(0xFF1E6FD9);
  static const _primaryBlueDark = Color(0xFF164EA6);
  static const _pageBg = Color(0xFFF3F6FB);
  static const _cardBorder = Color(0xFFD7E3F8);
  static const _inputFill = Color(0xFFF7FAFF);

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _qualificationCtrl = TextEditingController();
  final _designationCtrl = TextEditingController();
  bool _isEditingProfile = false;
  String? _profilePictureUrl;
  bool _isUploadingPicture = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<RoleDashboardController>().loadDoctor();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _qualificationCtrl.dispose();
    _designationCtrl.dispose();
    super.dispose();
  }

  void _bindProfile(dynamic p) {
    if (_isEditingProfile) return;
    _nameCtrl.text = p?.name ?? '';
    _emailCtrl.text = p?.email ?? '';
    _phoneCtrl.text = p?.phone ?? '';
    _qualificationCtrl.text = p?.qualification ?? '';
    _designationCtrl.text = p?.designation ?? '';
    _profilePictureUrl = p?.profilePictureUrl;
  }

  Future<void> _uploadProfilePicture() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;

    final file = picked.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read selected image file.')),
      );
      return;
    }

    setState(() => _isUploadingPicture = true);
    final url = await CloudinaryUpload.uploadAuto(
      bytes: bytes,
      folder: 'profile_pictures',
      fileName: file.name,
    );
    if (!mounted) return;
    setState(() => _isUploadingPicture = false);

    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            CloudinaryUpload.lastErrorMessage ??
                'Image upload failed. Please try again.',
          ),
        ),
      );
      return;
    }

    setState(() => _profilePictureUrl = url);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profile image uploaded.')));
  }

  Future<void> _saveProfile(RoleDashboardController c) async {
    final ok = await c.updateDoctorProfile(
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      qualification: _qualificationCtrl.text.trim(),
      designation: _designationCtrl.text.trim(),
      profilePictureUrl: _profilePictureUrl,
    );

    if (!mounted) return;
    if (ok) {
      setState(() => _isEditingProfile = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Doctor profile updated successfully.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(c.error ?? 'Failed to update doctor profile.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<RoleDashboardController>();
    final profile = c.doctorProfile;
    _bindProfile(profile);
    final theme = Theme.of(context);
    final updatedAt = DateFormat('d MMM yyyy').format(DateTime.now());

    return DashboardShell(
      child: c.isLoading && profile == null
          ? const Center(child: CircularProgressIndicator())
          : Container(
              color: _pageBg,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1120),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          colors: [_primaryBlueDark, _primaryBlue],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color.fromRGBO(22, 78, 166, 0.22),
                            blurRadius: 24,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 44,
                                backgroundColor: Colors.white,
                                backgroundImage:
                                    (_profilePictureUrl != null &&
                                        _profilePictureUrl!.isNotEmpty)
                                    ? NetworkImage(_profilePictureUrl!)
                                    : null,
                                child:
                                    (_profilePictureUrl == null ||
                                        _profilePictureUrl!.isEmpty)
                                    ? const Icon(
                                        Icons.person,
                                        size: 42,
                                        color: _primaryBlueDark,
                                      )
                                    : null,
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: InkWell(
                                  onTap:
                                      (_isEditingProfile &&
                                          !_isUploadingPicture)
                                      ? _uploadProfilePicture
                                      : null,
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: _isUploadingPicture
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: _primaryBlue,
                                            ),
                                          )
                                        : Icon(
                                            Icons.camera_alt,
                                            size: 15,
                                            color: _isEditingProfile
                                                ? _primaryBlue
                                                : const Color(0xFF94A3B8),
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _nameCtrl.text.trim().isEmpty
                                      ? 'Doctor Profile'
                                      : _nameCtrl.text.trim(),
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _designationCtrl.text.trim().isEmpty
                                      ? 'Medical Consultant'
                                      : _designationCtrl.text.trim(),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: const Color(0xFFE2EEFF),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Last updated: $updatedAt',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFFCFE3FF),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.tonalIcon(
                                onPressed: () {
                                  showChangePasswordDialog(
                                    context: context,
                                    onSubmit: (current, next) =>
                                        c.changeMyPassword(
                                          currentPassword: current,
                                          newPassword: next,
                                        ),
                                    getErrorMessage: () => c.error,
                                  );
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFDCEAFF),
                                  foregroundColor: _primaryBlueDark,
                                ),
                                icon: const Icon(Icons.lock_outline),
                                label: const Text('Change Password'),
                              ),
                              FilledButton.icon(
                                onPressed: c.isLoading
                                    ? null
                                    : () {
                                        if (_isEditingProfile) {
                                          _saveProfile(c);
                                        } else {
                                          setState(
                                            () => _isEditingProfile = true,
                                          );
                                        }
                                      },
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: _primaryBlueDark,
                                ),
                                icon: Icon(
                                  _isEditingProfile
                                      ? Icons.save_outlined
                                      : Icons.edit_outlined,
                                ),
                                label: Text(
                                  _isEditingProfile
                                      ? 'Save Changes'
                                      : 'Edit Profile',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1120),
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: _cardBorder),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.person_outline,
                                  color: _primaryBlueDark,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Personal Information',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F8EE),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    'ACTIVE ACCOUNT',
                                    style: TextStyle(
                                      color: Color(0xFF1E8E3E),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                      letterSpacing: 0.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _DoctorProfileField(
                                    label: 'FULL NAME',
                                    controller: _nameCtrl,
                                    enabled: _isEditingProfile,
                                    icon: Icons.badge_outlined,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _DoctorProfileField(
                                    label: 'EMAIL ADDRESS',
                                    controller: _emailCtrl,
                                    enabled: _isEditingProfile,
                                    icon: Icons.email_outlined,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _DoctorProfileField(
                                    label: 'PHONE NUMBER',
                                    controller: _phoneCtrl,
                                    enabled: _isEditingProfile,
                                    icon: Icons.call_outlined,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _DoctorProfileField(
                                    label: 'QUALIFICATION',
                                    controller: _qualificationCtrl,
                                    enabled: _isEditingProfile,
                                    icon: Icons.school_outlined,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _DoctorProfileField(
                              label: 'DESIGNATION',
                              controller: _designationCtrl,
                              enabled: _isEditingProfile,
                              icon: Icons.medical_services_outlined,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _isEditingProfile
                                  ? 'Tip: Use clear designation and qualification details for a professional profile.'
                                  : 'Click Edit Profile to update your details.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
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

class _DoctorProfileField extends StatelessWidget {
  const _DoctorProfileField({
    required this.label,
    required this.controller,
    required this.enabled,
    required this.icon,
  });

  final String label;
  final TextEditingController controller;
  final bool enabled;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: _DoctorProfilePageState._inputFill,
        prefixIcon: Icon(icon, color: _DoctorProfilePageState._primaryBlue),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: _DoctorProfilePageState._cardBorder,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: _DoctorProfilePageState._cardBorder,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: _DoctorProfilePageState._primaryBlue,
            width: 1.4,
          ),
        ),
      ),
    );
  }
}
