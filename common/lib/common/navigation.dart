import 'package:common/common/dialog.dart';
import 'package:common/common/module/journal/journal.dart';
import 'package:common/common/module/support/support.dart';
import 'package:common/common/route.dart';
import 'package:common/common/widget/common_clickable.dart';
import 'package:common/common/widget/settings/exceptions_section.dart';
import 'package:common/common/widget/settings/retention_section.dart';
import 'package:common/common/widget/settings/settings_screen.dart';
import 'package:common/common/widget/settings/vpn_devices_section.dart';
import 'package:common/common/widget/stats/stats_detail_section.dart';
import 'package:common/common/widget/stats/stats_filter.dart';
import 'package:common/common/widget/stats/stats_section.dart';
import 'package:common/common/widget/support/support_section.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/common/widget/top_bar.dart';
import 'package:common/common/widget/with_top_bar.dart';
import 'package:common/core/core.dart';
import 'package:common/family/module/device_v3/device.dart';
import 'package:common/family/module/family/family.dart';
import 'package:common/family/widget/device/device_screen.dart';
import 'package:common/family/widget/filters_section.dart';
import 'package:common/platform/custom/custom.dart';
import 'package:common/platform/stage/stage.dart';
import 'package:common/v6/widget/activity_screen.dart';
import 'package:common/v6/widget/advanced_screen.dart';
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
  support("/support", true), // Doesn't work in pane
  // V6 tabs
  activity("/activity", false),
  advanced("/advanced", false);

  final String path;
  final bool openInTablet;

  const Paths(this.path, this.openInTablet);
}

bool isTabletMode(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;
  return screenWidth > 1000;
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
  late final _filter = Core.get<JournalFilterValue>();
  late final _custom = Core.get<CustomStore>();
  late final _support = Core.get<SupportActor>();

  static late bool isTabletMode;

  static Function(Paths, Object?) openInTablet = (_, __) {};
  static Function(Paths? path) onNavigated = (_) {};

  static open(Paths path, {Object? arguments}) async {
    onNavigated(path);
    if (isTabletMode && path.openInTablet) {
      openInTablet(path, arguments);
      return;
    }

    final ctrl = Core.get<TopBarController>();
    ctrl.navigatorKey.currentState!.pushNamed(path.path, arguments: arguments);
  }

  StandardRoute generateRoute(BuildContext context, RouteSettings settings,
      {required Widget homeContent}) {
    if (settings.name == Paths.device.path) {
      final device = settings.arguments as FamilyDevice;
      return StandardRoute(
          settings: settings,
          builder: (context) => DeviceScreen(tag: device.device.deviceTag));
    }

    if (settings.name == Paths.deviceStats.path) {
      final device = settings.arguments as FamilyDevice;

      return StandardRoute(
        settings: settings,
        builder: (context) => WithTopBar(
          title: "activity section header".i18n,
          topBarTrailing: _getStatsAction(context, device.device.deviceTag),
          child:
              StatsSection(deviceTag: device.device.deviceTag, isHeader: false),
        ),
      );
    }

    if (settings.name == Paths.deviceFilters.path) {
      final device = settings.arguments as FamilyDevice;

      return StandardRoute(
        settings: settings,
        builder: (context) => WithTopBar(
          title: "family stats label blocklists".i18n,
          child: FamilyFiltersSection(profileId: device.profile.profileId),
        ),
      );
    }

    if (settings.name == Paths.deviceStatsDetail.path) {
      final entry = settings.arguments as UiJournalEntry;

      return StandardRoute(
        settings: settings,
        builder: (context) => WithTopBar(
          title: "family device title details".i18n,
          child: StatsDetailSection(entry: entry),
        ),
      );
    }

    if (settings.name == Paths.settings.path) {
      return StandardRoute(
          settings: settings, builder: (context) => const SettingsScreen());
    }

    if (settings.name == Paths.settingsExceptions.path) {
      return StandardRoute(
        settings: settings,
        builder: (context) => WithTopBar(
          title: "family stats title".i18n,
          topBarTrailing: _getExceptionsAction(context),
          child: const ExceptionsSection(),
        ),
      );
    }

    if (settings.name == Paths.settingsRetention.path) {
      return StandardRoute(
        settings: settings,
        builder: (context) => WithTopBar(
          title: "activity section header".i18n,
          child: const RetentionSection(),
        ),
      );
    }

    if (settings.name == Paths.settingsVpnDevices.path) {
      return StandardRoute(
        settings: settings,
        builder: (context) => WithTopBar(
          title: "web vpn devices header".i18n,
          child: const VpnDevicesSection(),
        ),
      );
    }

    if (settings.name == Paths.support.path) {
      return StandardRoute(
        settings: settings,
        builder: (context) => WithTopBar(
          title: "support action chat".i18n,
          topBarTrailing: _getSupportAction(context),
          child: const SupportSection(),
        ),
      );
    }

    if (settings.name == Paths.activity.path) {
      return StandardRoute(
          settings: settings, builder: (context) => const ActivityScreen());
    }

    if (settings.name == Paths.advanced.path) {
      return StandardRoute(
          settings: settings, builder: (context) => const AdvancedScreen());
    }

    return StandardRoute(settings: settings, builder: (context) => homeContent);
  }

  Widget? _getStatsAction(BuildContext context, DeviceTag tag) {
    return CommonClickable(
        onTap: () {
          showStatsFilterDialog(context, onConfirm: (filter) {
            _filter.now = filter;
          });
        },
        child: Text(
          "universal action search".i18n,
          style: TextStyle(
            color: context.theme.accent,
            fontSize: 17,
          ),
        ));
  }

  Widget? _getExceptionsAction(BuildContext context) {
    return CommonClickable(
        onTap: () {
          showAddExceptionDialog(context, onConfirm: (entry) {
            log(Markers.userTap).trace("addCustom", (m) async {
              await _custom.allow(entry, m);
            });
          });
        },
        child: Text(
          "Add",
          style: TextStyle(
            color: context.theme.accent,
            fontSize: 17,
          ),
        ));
  }

  Widget? _getSupportAction(BuildContext context) {
    return CommonClickable(
        onTap: () {
          Navigator.of(context).pop();
          _support.clearSession(Markers.userTap);
        },
        child: Text("support action end".i18n,
            style: const TextStyle(color: Colors.red, fontSize: 17)));
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
