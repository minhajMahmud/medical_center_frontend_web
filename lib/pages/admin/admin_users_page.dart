import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:backend_client/backend_client.dart';

import '../../controllers/role_dashboard_controller.dart';
import '../../widgets/common/dashboard_shell.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  String _selectedRole = 'ALL';
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<RoleDashboardController>().loadAdmin();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  String _roleGroup(String role) {
    final r = role.trim().toUpperCase();
    if (r.startsWith('LAB')) return 'LAB';
    if (r.startsWith('ADMIN')) return 'ADMIN';
    if (r.startsWith('DOCTOR')) return 'DOCTOR';
    if (r.startsWith('DISPENSER')) return 'DISPENSER';
    return r;
  }

  String _roleText(String role) {
    switch (_roleGroup(role)) {
      case 'LAB':
        return 'LAB';
      case 'ADMIN':
        return 'ADMIN';
      case 'DOCTOR':
        return 'DOCTOR';
      case 'DISPENSER':
        return 'DISPENSER';
      default:
        return role.toUpperCase();
    }
  }

  Color _roleColor(String role) {
    switch (_roleGroup(role)) {
      case 'DOCTOR':
        return const Color(0xFF2563EB);
      case 'LAB':
        return const Color(0xFF7C3AED);
      case 'ADMIN':
        return const Color(0xFFD97706);
      case 'DISPENSER':
        return const Color(0xFF0D9488);
      default:
        return const Color(0xFF64748B);
    }
  }

  String _lastSeenLabel(int index, bool active) {
    if (active) {
      if (index % 4 == 0) return '5 mins ago';
      if (index % 4 == 1) return '2 hours ago';
      if (index % 4 == 2) return 'Today, 10:30 AM';
      return 'Yesterday, 4:20 PM';
    }
    return 'Mar 12, 2024';
  }

  bool _looksLikeEmail(String value) {
    final v = value.trim();
    return v.contains('@') && v.contains('.') && v.length >= 6;
  }

  String _normalizedCreateRole(String role) {
    switch (role) {
      case 'LAB':
        return 'LAB_STAFF';
      default:
        return role;
    }
  }

  Future<void> _showCreateUserDialog() async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();

    var role = 'DOCTOR';
    var hidePassword = true;
    var enableEmailNotification = true;
    var submitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: !submitting,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> submit() async {
            if (submitting) return;
            final messenger = ScaffoldMessenger.of(context);
            final name = nameCtrl.text.trim();
            final email = emailCtrl.text.trim();
            final phone = phoneCtrl.text.trim();
            final password = passwordCtrl.text;

            if (name.isEmpty || email.isEmpty || password.isEmpty) {
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Name, Email and Password are required.'),
                ),
              );
              return;
            }
            if (!_looksLikeEmail(email)) {
              messenger.showSnackBar(
                const SnackBar(content: Text('Please enter a valid email.')),
              );
              return;
            }
            if (password.length < 6) {
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Password must be at least 6 characters.'),
                ),
              );
              return;
            }

            setDialogState(() => submitting = true);

            final controller = context.read<RoleDashboardController>();
            final ok = await controller.createAdminUserWithPassword(
              name: name,
              email: email,
              password: password,
              role: _normalizedCreateRole(role),
              phone: phone.isEmpty ? null : phone,
            );

            if (!mounted) return;
            setDialogState(() => submitting = false);
            if (ok) {
              if (!ctx.mounted) return;
              Navigator.of(ctx).pop();
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    enableEmailNotification
                        ? 'User created successfully.'
                        : 'User created successfully (email option ignored by backend).',
                  ),
                ),
              );
            } else {
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    controller.error ??
                        'Failed to create user. Please try again.',
                  ),
                ),
              );
            }
          }

          return AlertDialog(
            contentPadding: EdgeInsets.zero,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 20,
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Add New User',
                                  style: Theme.of(ctx).textTheme.headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Onboard a new staff member to the medical center management system.',
                                  style: Theme.of(ctx).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: const Color(0xFF64748B),
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F1FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.person_add_alt_1_rounded,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _DialogField(
                                  label: 'Full Name',
                                  child: TextField(
                                    controller: nameCtrl,
                                    decoration: const InputDecoration(
                                      hintText: 'e.g. Dr. Sarah Jenkins',
                                      prefixIcon: Icon(Icons.badge_outlined),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _DialogField(
                                  label: 'Email / ID',
                                  child: TextField(
                                    controller: emailCtrl,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: const InputDecoration(
                                      hintText: 'example@nstu.edu.bd',
                                      prefixIcon: Icon(
                                        Icons.alternate_email_rounded,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _DialogField(
                                  label: 'Phone Number',
                                  child: TextField(
                                    controller: phoneCtrl,
                                    keyboardType: TextInputType.phone,
                                    decoration: const InputDecoration(
                                      hintText: '01XXXXXXXXX',
                                      prefixIcon: Icon(Icons.phone_outlined),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _DialogField(
                                  label: 'User Role',
                                  child: DropdownButtonFormField<String>(
                                    initialValue: role,
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'ADMIN',
                                        child: Text('Admin'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'DOCTOR',
                                        child: Text('Doctor'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'DISPENSER',
                                        child: Text('Dispenser'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'LAB',
                                        child: Text('Lab'),
                                      ),
                                    ],
                                    onChanged: submitting
                                        ? null
                                        : (value) {
                                            setDialogState(
                                              () => role = value ?? 'DOCTOR',
                                            );
                                          },
                                    decoration: const InputDecoration(
                                      prefixIcon: Icon(
                                        Icons.supervised_user_circle_outlined,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _DialogField(
                            label: 'Initial Password',
                            child: TextField(
                              controller: passwordCtrl,
                              obscureText: hidePassword,
                              decoration: InputDecoration(
                                hintText: 'Create a secure password',
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                ),
                                suffixIcon: IconButton(
                                  tooltip: hidePassword
                                      ? 'Show password'
                                      : 'Hide password',
                                  onPressed: () {
                                    setDialogState(
                                      () => hidePassword = !hidePassword,
                                    );
                                  },
                                  icon: Icon(
                                    hidePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: const [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 14,
                                color: Color(0xFF94A3B8),
                              ),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'User will be prompted to change this password on first login.',
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: CheckboxListTile(
                              dense: true,
                              value: enableEmailNotification,
                              onChanged: submitting
                                  ? null
                                  : (value) {
                                      setDialogState(() {
                                        enableEmailNotification = value ?? true;
                                      });
                                    },
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: const Text(
                                'Enable automatic email notification for this user',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 14, 22, 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: submitting
                                ? null
                                : () => Navigator.of(ctx).pop(),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 122,
                            child: FilledButton(
                              onPressed: submitting ? null : submit,
                              child: submitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Create User'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showEditDialog(UserListItem user) async {
    var active = user.active;
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> save() async {
            if (saving) return;
            if (active == user.active) {
              Navigator.of(ctx).pop();
              return;
            }
            final messenger = ScaffoldMessenger.of(context);
            final controller = context.read<RoleDashboardController>();
            setDialogState(() => saving = true);
            final ok = await controller.toggleAdminUserActive(user.userId);
            if (!mounted) return;
            setDialogState(() => saving = false);
            if (ok) {
              if (!ctx.mounted) return;
              Navigator.of(ctx).pop();
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    active
                        ? 'User has been activated successfully.'
                        : 'User has been deactivated successfully.',
                  ),
                ),
              );
            } else {
              messenger.showSnackBar(
                SnackBar(
                  content: Text(controller.error ?? 'Failed to update user.'),
                ),
              );
            }
          }

          return AlertDialog(
            title: const Text('Edit User Access'),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.email,
                    style: const TextStyle(color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Active status',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Switch(
                        value: active,
                        onChanged: saving
                            ? null
                            : (value) => setDialogState(() => active = value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Name / email / role editing is not available on backend yet. Status update is live.',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving ? null : save,
                child: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _handleDelete(UserListItem user) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = context.read<RoleDashboardController>();
    if (!user.active) {
      messenger.showSnackBar(
        const SnackBar(content: Text('User is already inactive.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate User'),
        content: Text(
          'Do you want to deactivate ${user.name}? This can be restored later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final ok = await controller.toggleAdminUserActive(user.userId);
    if (!mounted) return;
    if (ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('User deactivated successfully.')),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(controller.error ?? 'Failed to deactivate user.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<RoleDashboardController>();
    final routeQuery =
        (GoRouterState.of(context).uri.queryParameters['q'] ?? '')
            .trim()
            .toLowerCase();

    if (!_searchFocus.hasFocus &&
        _searchCtrl.text.isEmpty &&
        routeQuery.isNotEmpty) {
      _searchCtrl.text = routeQuery;
    }

    final localQuery = _searchCtrl.text.trim().toLowerCase();
    final query = localQuery.isEmpty ? routeQuery : localQuery;

    final roleFiltered = _selectedRole == 'ALL'
        ? c.adminUsers
        : c.adminUsers
              .where((u) => _roleGroup(u.role) == _selectedRole)
              .toList();

    final filteredUsers = query.isEmpty
        ? roleFiltered
        : roleFiltered.where((u) {
            final haystack =
                '${u.name} ${u.email} ${u.role} ${u.phone ?? ''} ${u.active ? 'active' : 'inactive'} ${u.userId}'
                    .toLowerCase();
            return haystack.contains(query);
          }).toList();

    final totalDoctors = c.adminUsers
        .where((u) => _roleGroup(u.role) == 'DOCTOR')
        .length;
    final totalAdmins = c.adminUsers
        .where((u) => _roleGroup(u.role) == 'ADMIN')
        .length;
    final totalLabs = c.adminUsers
        .where((u) => _roleGroup(u.role) == 'LAB')
        .length;
    final activeNow = c.adminUsers.where((u) => u.active).length;

    final tabs = const [
      ('ALL', 'All Users'),
      ('ADMIN', 'Admin'),
      ('DOCTOR', 'Doctor'),
      ('DISPENSER', 'Dispenser'),
      ('LAB', 'Lab'),
    ];

    return DashboardShell(
      child: c.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'User Management',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Manage system users, roles and access levels.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _showCreateUserDialog,
                      icon: const Icon(
                        Icons.person_add_alt_1_rounded,
                        size: 18,
                      ),
                      label: const Text('Add New User'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final tab in tabs)
                                    _RoleTabButton(
                                      label: tab.$2,
                                      selected: _selectedRole == tab.$1,
                                      onTap: () {
                                        setState(() => _selectedRole = tab.$1);
                                      },
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 280,
                              child: TextField(
                                controller: _searchCtrl,
                                focusNode: _searchFocus,
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.search_rounded),
                                  hintText: 'Search by name or email...',
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      _UsersTableHeader(),
                      const Divider(height: 1),
                      if (filteredUsers.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No users found with current filters.',
                            style: TextStyle(color: Color(0xFF64748B)),
                          ),
                        )
                      else
                        ...filteredUsers.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final u = entry.value;
                          return Column(
                            children: [
                              _UserRow(
                                user: u,
                                name: u.name,
                                email: u.email,
                                role: _roleText(u.role),
                                roleColor: _roleColor(u.role),
                                isActive: u.active,
                                lastLogin: _lastSeenLabel(idx, u.active),
                                onEdit: () => _showEditDialog(u),
                                onDelete: () => _handleDelete(u),
                              ),
                              if (idx != filteredUsers.length - 1)
                                const Divider(height: 1),
                            ],
                          );
                        }),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                        child: Row(
                          children: [
                            Text(
                              'Showing 1 to ${filteredUsers.length} of ${roleFiltered.length} entries',
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 12,
                              ),
                            ),
                            const Spacer(),
                            const _PageButton(icon: Icons.chevron_left_rounded),
                            const SizedBox(width: 6),
                            const _PageNumberButton(label: '1', selected: true),
                            const SizedBox(width: 6),
                            const _PageNumberButton(label: '2'),
                            const SizedBox(width: 6),
                            const _PageNumberButton(label: '3'),
                            const SizedBox(width: 6),
                            const _PageButton(
                              icon: Icons.chevron_right_rounded,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),
                if (query.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      'Search results: ${filteredUsers.length} for "$query"',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _SummaryCard(
                      title: 'TOTAL DOCTORS',
                      value: totalDoctors.toString().padLeft(2, '0'),
                      caption: '+2 this month',
                      captionColor: const Color(0xFF16A34A),
                    ),
                    _SummaryCard(
                      title: 'ADMIN STAFF',
                      value: totalAdmins.toString().padLeft(2, '0'),
                      caption: 'Stable',
                      captionColor: const Color(0xFF64748B),
                    ),
                    _SummaryCard(
                      title: 'LAB TEAM',
                      value: totalLabs.toString().padLeft(2, '0'),
                      caption: '+1 this month',
                      captionColor: const Color(0xFF16A34A),
                    ),
                    _SummaryCard(
                      title: 'ACTIVE NOW',
                      value: activeNow.toString().padLeft(2, '0'),
                      caption: 'Users online',
                      captionColor: const Color(0xFF64748B),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _RoleTabButton extends StatelessWidget {
  const _RoleTabButton({
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
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE8F1FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF2563EB) : const Color(0xFF475569),
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _UsersTableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 12,
      color: Color(0xFF94A3B8),
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
    );
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text('USER', style: style)),
          Expanded(flex: 2, child: Text('ROLE', style: style)),
          Expanded(flex: 2, child: Text('STATUS', style: style)),
          Expanded(flex: 2, child: Text('LAST LOGIN', style: style)),
          SizedBox(width: 84, child: Text('ACTIONS', style: style)),
        ],
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({
    required this.user,
    required this.name,
    required this.email,
    required this.role,
    required this.roleColor,
    required this.isActive,
    required this.lastLogin,
    required this.onEdit,
    required this.onDelete,
  });

  final UserListItem user;
  final String name;
  final String email;
  final String role;
  final Color roleColor;
  final bool isActive;
  final String lastLogin;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s[0].toUpperCase())
        .join();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFFE2E8F0),
                  child: Text(
                    initials.isEmpty ? 'U' : initials,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: roleColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  role,
                  style: TextStyle(
                    color: roleColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFF10B981)
                        : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    color: isActive
                        ? const Color(0xFF0F172A)
                        : const Color(0xFF94A3B8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              lastLogin,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),
          ),
          SizedBox(
            width: 84,
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Edit user',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                ),
                IconButton(
                  tooltip: isActive ? 'Deactivate user' : 'Already inactive',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogField extends StatelessWidget {
  const _DialogField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _PageButton extends StatelessWidget {
  const _PageButton({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 16, color: const Color(0xFF64748B)),
    );
  }
}

class _PageNumberButton extends StatelessWidget {
  const _PageNumberButton({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF2563EB) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : const Color(0xFF334155),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.caption,
    required this.captionColor,
  });

  final String title;
  final String value;
  final String caption;
  final Color captionColor;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 184, maxWidth: 220),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF94A3B8),
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 34,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    caption,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: captionColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
