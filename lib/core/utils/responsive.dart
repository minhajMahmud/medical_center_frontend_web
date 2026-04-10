import 'package:flutter/widgets.dart';

import '../constants/app_breakpoints.dart';

enum ScreenType { mobile, tablet, desktop }

class Responsive {
  static ScreenType getType(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width > AppBreakpoints.desktop) return ScreenType.desktop;
    if (width > AppBreakpoints.tablet) return ScreenType.tablet;
    return ScreenType.mobile;
  }

  static bool isMobile(BuildContext context) =>
      getType(context) == ScreenType.mobile;

  static bool isTablet(BuildContext context) =>
      getType(context) == ScreenType.tablet;

  static bool isDesktop(BuildContext context) =>
      getType(context) == ScreenType.desktop;
}
