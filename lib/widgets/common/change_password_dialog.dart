import 'package:flutter/material.dart';

typedef ChangePasswordExecutor =
    Future<bool> Function(String currentPassword, String newPassword);

Future<void> showChangePasswordDialog({
  required BuildContext context,
  required ChangePasswordExecutor onSubmit,
  String successMessage = 'Password changed successfully.',
  String failureMessage = 'Password change failed.',
  String? Function()? getErrorMessage,
}) async {
  final currentCtrl = TextEditingController();
  final newCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();

  final submit = await showDialog<bool>(
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
              decoration: const InputDecoration(labelText: 'Current Password'),
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

  if (submit != true) {
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
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All password fields are required.')),
    );
    return;
  }

  if (next != confirm) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('New password and confirm password must match.'),
      ),
    );
    return;
  }

  final ok = await onSubmit(current, next);
  if (!context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        ok ? successMessage : (getErrorMessage?.call() ?? failureMessage),
      ),
    ),
  );
}
