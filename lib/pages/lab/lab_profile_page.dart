import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../../controllers/role_dashboard_controller.dart';
import '../../utils/cloudinary_upload.dart';
import '../../widgets/common/dashboard_shell.dart';

class LabProfilePage extends StatefulWidget {
  const LabProfilePage({super.key});

  @override
  State<LabProfilePage> createState() => _LabProfilePageState();
}

class _LabProfilePageState extends State<LabProfilePage> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _qualificationCtrl = TextEditingController();
  final _designationCtrl = TextEditingController();
  String? _profilePictureUrl;
  bool _isUploadingPicture = false;

  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<RoleDashboardController>().loadLab();
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

  void _bindProfile(dynamic profile) {
    if (_isEditing) return;
    _nameCtrl.text = profile.name;
    _emailCtrl.text = profile.email;
    _phoneCtrl.text = profile.phone;
    _qualificationCtrl.text = profile.qualification;
    _designationCtrl.text = profile.designation;
    _profilePictureUrl = profile.profilePictureUrl;
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
        const SnackBar(content: Text('Image upload failed. Please try again.')),
      );
      return;
    }

    setState(() => _profilePictureUrl = url);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profile image uploaded.')));
  }

  Future<void> _save(RoleDashboardController c) async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final qualification = _qualificationCtrl.text.trim();
    final designation = _designationCtrl.text.trim();

    if ([
      name,
      email,
      phone,
      qualification,
      designation,
    ].any((e) => e.isEmpty)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('All fields are required.')));
      return;
    }
    if (!email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email.')),
      );
      return;
    }

    final ok = await c.updateLabStaffProfile(
      name: name,
      email: email,
      phone: phone,
      qualification: qualification,
      designation: designation,
      profilePictureUrl: _profilePictureUrl,
    );

    if (!mounted) return;

    if (ok) {
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(c.error ?? 'Failed to update profile.')),
      );
    }
  }

  Future<void> _openChangePasswordDialog(RoleDashboardController c) async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    final shouldSubmit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Password'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current Password',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: newCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New Password'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm New Password',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Update Password'),
          ),
        ],
      ),
    );

    if (shouldSubmit != true) {
      currentCtrl.dispose();
      newCtrl.dispose();
      confirmCtrl.dispose();
      return;
    }

    final current = currentCtrl.text.trim();
    final next = newCtrl.text.trim();
    final confirm = confirmCtrl.text.trim();

    currentCtrl.dispose();
    newCtrl.dispose();
    confirmCtrl.dispose();

    if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All password fields are required.')),
      );
      return;
    }
    if (next.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New password must be at least 6 characters.'),
        ),
      );
      return;
    }
    if (next != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New password and confirm password do not match.'),
        ),
      );
      return;
    }

    final ok = await c.changeMyPassword(
      currentPassword: current,
      newPassword: next,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Password changed successfully.'
              : (c.error ?? 'Password change failed.'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<RoleDashboardController>();
    final summary = c.labSummary;
    final profile = c.labProfile;

    if (profile != null) {
      _bindProfile(profile);
    }

    return DashboardShell(
      child: c.isLoading && profile == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Text(
                  'Staff Profile & Management',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 94,
                          height: 94,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0B5EA8), Color(0xFF0EA5E9)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child:
                              (_profilePictureUrl != null &&
                                  _profilePictureUrl!.isNotEmpty)
                              ? Image.network(
                                  _profilePictureUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.person_rounded,
                                    color: Colors.white,
                                    size: 46,
                                  ),
                                )
                              : const Icon(
                                  Icons.person_rounded,
                                  color: Colors.white,
                                  size: 46,
                                ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile?.name ?? 'Lab Staff',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '${profile?.designation.isNotEmpty == true ? profile!.designation : 'Lab Staff'} • Database Connected',
                              ),
                              SizedBox(height: 4),
                              Text('Email: ${profile?.email ?? '-'}'),
                              SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: (!_isEditing || _isUploadingPicture)
                                    ? null
                                    : _uploadProfilePicture,
                                icon: _isUploadingPicture
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.upload),
                                label: Text(
                                  _isUploadingPicture
                                      ? 'Uploading...'
                                      : 'Upload Picture',
                                ),
                              ),
                              SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [
                                  _StatusTag(
                                    text: 'ACTIVE',
                                    bg: Color(0xFFE6FAEF),
                                    fg: Color(0xFF1C8B4B),
                                  ),
                                  _StatusTag(
                                    text: 'LAB UNIT',
                                    bg: Color(0xFFE8F1FF),
                                    fg: Color(0xFF0B5EA8),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton(
                          onPressed: c.isLoading
                              ? null
                              : () {
                                  if (_isEditing) {
                                    _save(c);
                                  } else {
                                    setState(() => _isEditing = true);
                                  }
                                },
                          child: Text(
                            _isEditing ? 'Save Changes' : 'Edit Profile',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 7,
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Professional Information',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: _EditableField(
                                      title: 'FULL NAME',
                                      controller: _nameCtrl,
                                      enabled: _isEditing,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: _EditableField(
                                      title: 'EMAIL',
                                      controller: _emailCtrl,
                                      enabled: _isEditing,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _EditableField(
                                      title: 'PHONE',
                                      controller: _phoneCtrl,
                                      enabled: _isEditing,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: _EditableField(
                                      title: 'QUALIFICATION',
                                      controller: _qualificationCtrl,
                                      enabled: _isEditing,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _EditableField(
                                title: 'DESIGNATION',
                                controller: _designationCtrl,
                                enabled: _isEditing,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        _openChangePasswordDialog(c),
                                    icon: const Icon(Icons.lock_outline),
                                    label: const Text('Change Password'),
                                  ),
                                  const SizedBox(width: 8),
                                  if (_isEditing)
                                    OutlinedButton(
                                      onPressed: () {
                                        setState(() => _isEditing = false);
                                        if (profile != null)
                                          _bindProfile(profile);
                                      },
                                      child: const Text('Cancel'),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          _ProfileStat(
                            title: 'Today Pending',
                            value: '${summary?.todayPendingUploads ?? 0}',
                            icon: Icons.pending_actions,
                            color: const Color(0xFFE8F1FF),
                          ),
                          const SizedBox(height: 10),
                          _ProfileStat(
                            title: 'Today Submitted',
                            value: '${summary?.todaySubmitted ?? 0}',
                            icon: Icons.task_alt,
                            color: const Color(0xFFDCFCE7),
                          ),
                          const SizedBox(height: 10),
                          _ProfileStat(
                            title: 'Available Tests',
                            value:
                                '${c.labAvailableTests.where((e) => e.available).length}',
                            icon: Icons.biotech_outlined,
                            color: const Color(0xFFFCE7F3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.text, required this.bg, required this.fg});

  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: .3,
        ),
      ),
    );
  }
}

class _EditableField extends StatelessWidget {
  const _EditableField({
    required this.title,
    required this.controller,
    required this.enabled,
  });

  final String title;
  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: title,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(backgroundColor: color, child: Icon(icon)),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(title),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
