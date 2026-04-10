import 'package:flutter/material.dart';

import '../../core/utils/responsive.dart';
import '../navbar/app_top_navigation_bar.dart';
import '../sidebar/dashboard_sidebar.dart';

class DashboardShell extends StatelessWidget {
  const DashboardShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);

    return Scaffold(
      appBar: AppTopNavigationBar(showMenuButton: mobile),
      drawer: mobile
          ? const Drawer(child: SafeArea(child: DashboardSidebar()))
          : null,
      body: Row(
        children: [
          if (!mobile) const DashboardSidebar(),
          Expanded(
            child: Padding(padding: const EdgeInsets.all(16), child: child),
          ),
        ],
      ),
    );
  }
}
