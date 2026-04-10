import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../core/utils/role_utils.dart';

class _NavItem {
  const _NavItem({
    required this.route,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String route;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class DashboardSidebar extends StatelessWidget {
  const DashboardSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthController>().appRole;

    if (role == AppRole.lab) {
      return const _LabDashboardSidebar();
    }

    if (role == AppRole.admin) {
      return const _AdminDashboardSidebar();
    }

    final items = _itemsForRole(role);
    final path = GoRouterState.of(context).uri.path;
    final selected = _indexFromLocation(path, items);
    final auth = context.read<AuthController>();

    return NavigationRail(
      selectedIndex: selected,
      onDestinationSelected: (index) {
        context.go(items[index].route);
      },
      labelType: NavigationRailLabelType.all,
      trailing: Expanded(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Tooltip(
              message: 'Logout',
              child: IconButton(
                onPressed: () async {
                  await auth.logout();
                  if (context.mounted) context.go('/login');
                },
                icon: const Icon(Icons.logout_rounded),
                color: Colors.red,
              ),
            ),
          ),
        ),
      ),
      destinations: [
        for (final item in items)
          NavigationRailDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.selectedIcon),
            label: Text(item.label),
          ),
      ],
    );
  }

  int _indexFromLocation(String path, List<_NavItem> items) {
    for (var i = 0; i < items.length; i++) {
      if (path.startsWith(items[i].route)) return i;
    }
    return 0;
  }

  List<_NavItem> _itemsForRole(AppRole role) {
    switch (role) {
      case AppRole.patient:
        return const [
          _NavItem(
            route: '/patient/dashboard',
            label: 'Dashboard',
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard,
          ),
          _NavItem(
            route: '/patient/reports',
            label: 'Prescriptions & Reports',
            icon: Icons.description_outlined,
            selectedIcon: Icons.description,
          ),
          _NavItem(
            route: '/patient/appointments',
            label: 'Appointments',
            icon: Icons.event_note_outlined,
            selectedIcon: Icons.event_note,
          ),
          _NavItem(
            route: '/patient/profile',
            label: 'Profile',
            icon: Icons.person_outline,
            selectedIcon: Icons.person,
          ),
          _NavItem(
            route: '/patient/lab-tests',
            label: 'Lab Tests',
            icon: Icons.science_outlined,
            selectedIcon: Icons.science,
          ),
          _NavItem(
            route: '/patient/payments',
            label: 'Payments',
            icon: Icons.payments_outlined,
            selectedIcon: Icons.payments,
          ),
          _NavItem(
            route: '/patient/staff',
            label: 'Medical Staff',
            icon: Icons.local_hospital_outlined,
            selectedIcon: Icons.local_hospital,
          ),
        ];
      case AppRole.doctor:
        return const [
          _NavItem(
            route: '/doctor/dashboard',
            label: 'Dashboard',
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard,
          ),
          _NavItem(
            route: '/doctor/patients',
            label: 'Patients',
            icon: Icons.groups_outlined,
            selectedIcon: Icons.groups,
          ),
          _NavItem(
            route: '/doctor/appointments',
            label: 'Appointments',
            icon: Icons.calendar_month_outlined,
            selectedIcon: Icons.calendar_month,
          ),
          _NavItem(
            route: '/doctor/reports',
            label: 'Reports',
            icon: Icons.description_outlined,
            selectedIcon: Icons.description,
          ),
          _NavItem(
            route: '/doctor/profile',
            label: 'Profile',
            icon: Icons.person_outline,
            selectedIcon: Icons.person,
          ),
        ];
      case AppRole.admin:
        return const [
          _NavItem(
            route: '/admin/dashboard',
            label: 'Dashboard',
            icon: Icons.admin_panel_settings_outlined,
            selectedIcon: Icons.admin_panel_settings,
          ),
          _NavItem(
            route: '/admin/users',
            label: 'User Management',
            icon: Icons.groups_outlined,
            selectedIcon: Icons.groups,
          ),
          _NavItem(
            route: '/admin/roster',
            label: 'Staff Rostering',
            icon: Icons.event_note_outlined,
            selectedIcon: Icons.event_note,
          ),
          _NavItem(
            route: '/admin/inventory',
            label: 'Inventory',
            icon: Icons.inventory_2_outlined,
            selectedIcon: Icons.inventory_2,
          ),
          _NavItem(
            route: '/admin/ambulance',
            label: 'Ambulance',
            icon: Icons.local_taxi_outlined,
            selectedIcon: Icons.local_taxi,
          ),
        ];
      case AppRole.lab:
        return const [
          _NavItem(
            route: '/lab/dashboard',
            label: 'Dashboard',
            icon: Icons.science_outlined,
            selectedIcon: Icons.science,
          ),
          _NavItem(
            route: '/lab/results',
            label: 'Results',
            icon: Icons.biotech_outlined,
            selectedIcon: Icons.biotech,
          ),
        ];
      case AppRole.dispenser:
        return const [
          _NavItem(
            route: '/dispenser/dashboard',
            label: 'Home',
            icon: Icons.home_outlined,
            selectedIcon: Icons.home,
          ),
          _NavItem(
            route: '/dispenser/history',
            label: 'Dispense',
            icon: Icons.local_pharmacy_outlined,
            selectedIcon: Icons.local_pharmacy,
          ),
          _NavItem(
            route: '/dispenser/stock',
            label: 'Inventory',
            icon: Icons.inventory_2_outlined,
            selectedIcon: Icons.inventory_2,
          ),
          _NavItem(
            route: '/dispenser/profile',
            label: 'Profile',
            icon: Icons.person_outline,
            selectedIcon: Icons.person,
          ),
        ];
      case AppRole.unknown:
        return const [
          _NavItem(
            route: '/home',
            label: 'Home',
            icon: Icons.home_outlined,
            selectedIcon: Icons.home,
          ),
        ];
    }
  }
}

class _AdminDashboardSidebar extends StatelessWidget {
  const _AdminDashboardSidebar();

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final auth = context.read<AuthController>();

    final items = const [
      _NavItem(
        route: '/admin/dashboard',
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
      ),
      _NavItem(
        route: '/admin/users',
        label: 'User Management',
        icon: Icons.groups_outlined,
        selectedIcon: Icons.groups,
      ),
      _NavItem(
        route: '/admin/roster',
        label: 'Staff Rostering',
        icon: Icons.event_note_outlined,
        selectedIcon: Icons.event_note,
      ),
      _NavItem(
        route: '/admin/inventory',
        label: 'Inventory',
        icon: Icons.inventory_2_outlined,
        selectedIcon: Icons.inventory_2,
      ),
      _NavItem(
        route: '/admin/ambulance',
        label: 'Ambulance',
        icon: Icons.local_taxi_outlined,
        selectedIcon: Icons.local_taxi,
      ),
    ];

    return Container(
      width: 248,
      color: const Color(0xFFF3F4F6),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Container(
                    height: 36,
                    width: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D4ED8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.local_hospital_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NSTU Medical',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Admin Portal',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final selected = path.startsWith(item.route);
                  return Container(
                    decoration: selected
                        ? BoxDecoration(
                            color: const Color(0xFFE8F0FE),
                            borderRadius: BorderRadius.circular(10),
                            border: Border(
                              left: BorderSide(
                                color: const Color(0xFF1D4ED8),
                                width: 3,
                              ),
                            ),
                          )
                        : null,
                    child: ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      leading: Icon(
                        selected ? item.selectedIcon : item.icon,
                        color: selected
                            ? const Color(0xFF1D4ED8)
                            : const Color(0xFF475569),
                        size: 20,
                      ),
                      title: Text(
                        item.label,
                        style: TextStyle(
                          color: selected
                              ? const Color(0xFF1D4ED8)
                              : const Color(0xFF0F172A),
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      onTap: () => context.go(item.route),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(0xFFF59E0B),
                      child: Text(
                        'A',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Administrator',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'Super Admin',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Logout',
                      onPressed: () async {
                        await auth.logout();
                        if (context.mounted) context.go('/login');
                      },
                      icon: const Icon(Icons.logout_rounded),
                      color: const Color(0xFF64748B),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabDashboardSidebar extends StatelessWidget {
  const _LabDashboardSidebar();

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final auth = context.read<AuthController>();

    final items = const [
      _NavItem(
        route: '/lab/dashboard',
        label: 'Home',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
      ),
      _NavItem(
        route: '/lab/payments',
        label: 'Payments',
        icon: Icons.payments_outlined,
        selectedIcon: Icons.payments,
      ),
      _NavItem(
        route: '/lab/upload',
        label: 'Upload',
        icon: Icons.cloud_upload_outlined,
        selectedIcon: Icons.cloud_upload,
      ),
      _NavItem(
        route: '/lab/manage-test',
        label: 'ManageTest',
        icon: Icons.manage_accounts_outlined,
        selectedIcon: Icons.manage_accounts,
      ),
      _NavItem(
        route: '/lab/profile',
        label: 'Profile',
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
      ),
      _NavItem(
        route: '/lab/analytics',
        label: 'Analytics',
        icon: Icons.analytics_outlined,
        selectedIcon: Icons.analytics,
      ),
      _NavItem(
        route: '/lab/support',
        label: 'Support',
        icon: Icons.help_outline,
        selectedIcon: Icons.help,
      ),
      _NavItem(
        route: '/lab/announcements',
        label: 'Announcements',
        icon: Icons.campaign_outlined,
        selectedIcon: Icons.campaign,
      ),
    ];

    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0B5EA8), Color(0xFF0EA5E9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Column(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.person, color: Colors.white, size: 32),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'lab1',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Lab Technician',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 2),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final selected = path.startsWith(item.route);
                  return ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    selected: selected,
                    selectedTileColor: const Color(0xFFE8F1FF),
                    leading: Icon(selected ? item.selectedIcon : item.icon),
                    title: Text(item.label),
                    onTap: () => context.go(item.route),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                children: [
                  ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    selected: path.startsWith('/lab/settings'),
                    selectedTileColor: const Color(0xFFE8F1FF),
                    leading: const Icon(Icons.settings_outlined),
                    title: const Text('Settings'),
                    onTap: () => context.go('/lab/settings'),
                  ),
                  ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    leading: const Icon(
                      Icons.logout_rounded,
                      color: Colors.red,
                    ),
                    title: const Text(
                      'Logout',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () async {
                      await auth.logout();
                      if (context.mounted) context.go('/login');
                    },
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
