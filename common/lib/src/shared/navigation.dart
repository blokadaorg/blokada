import 'package:common/src/features/journal/domain/journal.dart';
import 'package:common/src/features/support/domain/support.dart';
import 'package:common/src/shared/route.dart';
import 'package:common/src/features/settings/ui/settings_screen.dart';
import 'package:common/src/features/stats/ui/top_domains.dart';
import 'package:common/src/shared/ui/top_bar.dart';
import 'package:common/src/shared/ui/with_top_bar.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/app_variants/family/module/family/family.dart';
import 'package:common/src/app_variants/family/widget/device/device_screen.dart';
import 'package:common/src/platform/stage/stage.dart';
import 'package:common/src/app_variants/v6/widget/activity_screen.dart';
import 'package:common/src/app_variants/v6/widget/advanced_screen.dart';
import 'package:common/src/app_variants/v6/widget/privacy_pulse_screen.dart';
import 'package:common/src/shared/layout/detail_pane_host.dart';
import 'package:common/src/shared/layout/detail_route.dart';
import 'package:common/src/shared/layout/window_shape.dart';
import 'package:flutter/material.dart';

enum Paths {
  home("/", false),
  device("/device", false),
  deviceFilters("/device/filters", true),
  deviceStats("/device/stats", true),
  deviceStatsDetail("/device/stats/detail", true),
  settings("/settings", false),
  settingsExceptions("/settings/exceptions", true),
  settingsAccount("/settings/account", true),
  settingsRetention("/settings/retention", true),
  settingsVpnDevices("/settings/vpn", true),
  settingsVpnBypass("/settings/bypass", true),
  support("/support", true), // Doesn't work in pane
  // V6 tabs
  activity("/activity", false),
  privacyPulse("/privacyPulse", false),
  advanced("/advanced", false);

  final String path;
  final bool openInTablet;

  const Paths(this.path, this.openInTablet);
}

/// Legacy tablet check kept as a delegate while screens migrate onto
/// [WindowShape]; deleted in the layout-overhaul cleanup stage.
@Deprecated("Use windowShapeOf(context) == WindowShape.expanded instead")
bool isTabletMode(BuildContext context) {
  return windowShapeOf(context) == WindowShape.expanded;
}

const maxContentWidth = 500.0;
const maxContentWidthTablet = 1500.0;

double getTopPadding(BuildContext context) {
  final topPadding = MediaQuery.of(context).padding.top;
  final noNotch = topPadding < 30;
  final android = PlatformInfo().isSmallAndroid(context) ? 24.0 : 0.0;
  return (noNotch ? 100 : 68) + android; // I don't get it either
}

class Navigation with Logging {
  static late bool isTabletMode;

  static Function(Paths, Object?) openInTablet = (_, __) {};
  static Function(Paths? path) onNavigated = (_) {};
  // Track last navigated path directly from Navigation; StageStore is being phased out and
  // should not be treated as the source of truth for current UI route.
  static Paths? lastPath;

  static open(Paths path, {Object? arguments}) async {
    onNavigated(path);
    lastPath = path;

    // Two-pane screens (WithDetailPane) claim their detail paths; anything
    // unclaimed — including detail paths while no pane is visible — pushes
    // as a regular full-screen route.
    if (Core.get<DetailPaneHosts>().openInPane(path, arguments)) return;

    // Legacy pane callback for screens not yet migrated to WithDetailPane;
    // removed once v6 Activity and Privacy Pulse move over.
    if (isTabletMode && path.openInTablet) {
      openInTablet(path, arguments);
      return;
    }

    final ctrl = Core.get<TopBarController>();
    ctrl.navigatorKey.currentState!.pushNamed(path.path, arguments: arguments);
  }

  StandardRoute generateRoute(BuildContext context, RouteSettings settings,
      {required Widget homeContent}) {
    // Detail routes (title, body, trailing action) are defined once in
    // DetailRoutes, shared with the top-bar title stack and the tablet pane.
    final detail = Core.get<DetailRoutes>().resolveByName(settings.name);
    if (detail?.body != null) {
      return StandardRoute(
        settings: settings,
        builder: (context) => WithTopBar(
          title: detail!.title(settings.arguments),
          topBarTrailing: detail.trailing?.call(context, settings.arguments),
          child: detail.body!(context, settings.arguments),
        ),
      );
    }

    if (settings.name == Paths.device.path) {
      final device = settings.arguments as FamilyDevice;
      return StandardRoute(
          settings: settings, builder: (context) => DeviceScreen(tag: device.device.deviceTag));
    }

    if (settings.name == Paths.settings.path) {
      return StandardRoute(settings: settings, builder: (context) => const SettingsScreen());
    }

    if (settings.name == Paths.activity.path) {
      return StandardRoute(settings: settings, builder: (context) => const ActivityScreen());
    }

    if (settings.name == Paths.privacyPulse.path) {
      ToplistRange? initialRange;
      final args = settings.arguments;
      if (args is Map) {
        final rangeArg = args['toplistRange'];
        if (rangeArg is ToplistRange) {
          initialRange = rangeArg;
        } else if (rangeArg is String) {
          if (rangeArg == "weekly") initialRange = ToplistRange.weekly;
          if (rangeArg == "daily") initialRange = ToplistRange.daily;
        }
      }
      return StandardRoute(
        settings: settings,
        builder: (context) => PrivacyPulseScreen(
          initialToplistRange: initialRange,
        ),
      );
    }

    if (settings.name == Paths.advanced.path) {
      return StandardRoute(settings: settings, builder: (context) => const AdvancedScreen());
    }

    return StandardRoute(settings: settings, builder: (context) => homeContent);
  }
}

class NavigationPopObserver extends NavigatorObserver {
  late final _filter = Core.get<JournalFilterValue>();
  late final _unread = Core.get<SupportUnreadActor>();
  late final _stage = Core.get<StageStore>();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is StandardRoute && previousRoute is StandardRoute) {
      final r = route.settings;
      final p = previousRoute.settings;

      // Resets journal filter when leaving device section
      if (r.name == Paths.device.path && p.name == Paths.home.path) {
        _filter.reset();
      }

      // Resets some flag when leaving support section
      // TODO: this needs rework and merging with StageStore
      if (r.name == Paths.support.path) {
        _unread.wentBackFromSupport();
      }

      // V6 hacky tab management, handle going back to home
      if (!Core.act.isFamily && p.name == Paths.home.path) {
        _stage.setRoute(Paths.home.path, Markers.root);
      }
    }
  }
}
