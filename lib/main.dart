import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'controllers/appointment_controller.dart';
import 'controllers/auth_controller.dart';
import 'controllers/role_dashboard_controller.dart';
import 'core/config/app_router.dart';
import 'core/themes/app_theme.dart';
import 'services/appointment_service.dart';
import 'services/auth_service.dart';
import 'services/role_dashboard_service.dart';

void main() {
  runApp(const WebApp());
}

class WebApp extends StatefulWidget {
  const WebApp({super.key});

  @override
  State<WebApp> createState() => _WebAppState();
}

class _WebAppState extends State<WebApp> {
  late final AuthController _authController;
  late GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authController = AuthController(AuthService());
    _router = createAppRouter(_authController);
    Future.microtask(_authController.bootstrap);
  }

  @override
  void reassemble() {
    super.reassemble();
    _router.dispose();
    _router = createAppRouter(_authController);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authController),
        ChangeNotifierProvider(
          create: (_) => AppointmentController(AppointmentService()),
        ),
        ChangeNotifierProvider(
          create: (_) => RoleDashboardController(RoleDashboardService()),
        ),
      ],
      child: MaterialApp.router(
        title: 'NSTU Medical Center Web',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: _router,
      ),
    );
  }
}
