import 'package:flutter/material.dart';

class RoleProfileFormCard extends StatelessWidget {
  const RoleProfileFormCard({
    super.key,
    required this.title,
    required this.isEditing,
    required this.isBusy,
    required this.nameController,
    required this.emailController,
    required this.phoneController,
    required this.qualificationController,
    required this.designationController,
    this.profileImageUrl,
    this.isUploadingImage = false,
    this.emailEditable = true,
    this.onUploadPicture,
    required this.onChangePassword,
    required this.onToggleEditOrSave,
  });

  final String title;
  final bool isEditing;
  final bool isBusy;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController qualificationController;
  final TextEditingController designationController;
  final String? profileImageUrl;
  final bool isUploadingImage;
  final bool emailEditable;
  final VoidCallback? onUploadPicture;
  final VoidCallback onChangePassword;
  final VoidCallback onToggleEditOrSave;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: const Color(0xFFE8F1FF),
                  backgroundImage:
                      (profileImageUrl != null && profileImageUrl!.isNotEmpty)
                      ? NetworkImage(profileImageUrl!)
                      : null,
                  child: (profileImageUrl == null || profileImageUrl!.isEmpty)
                      ? const Icon(Icons.person, size: 30)
                      : null,
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: (isUploadingImage || onUploadPicture == null)
                      ? null
                      : onUploadPicture,
                  icon: isUploadingImage
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload),
                  label: Text(
                    isUploadingImage ? 'Uploading...' : 'Upload Picture',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: onChangePassword,
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('Change Password'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: isBusy ? null : onToggleEditOrSave,
                  child: Text(isEditing ? 'Save Changes' : 'Edit Profile'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ProfileField(
                    label: 'Full Name',
                    controller: nameController,
                    enabled: isEditing,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ProfileField(
                    label: 'Email',
                    controller: emailController,
                    enabled: isEditing && emailEditable,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ProfileField(
                    label: 'Phone',
                    controller: phoneController,
                    enabled: isEditing,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ProfileField(
                    label: 'Qualification',
                    controller: qualificationController,
                    enabled: isEditing,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _ProfileField(
              label: 'Designation',
              controller: designationController,
              enabled: isEditing,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.label,
    required this.controller,
    required this.enabled,
  });

  final String label;
  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
