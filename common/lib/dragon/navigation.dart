import 'package:common/common/model/model.dart';
import 'package:common/common/widget/common_clickable.dart';
import 'package:common/common/widget/settings/exceptions_section.dart';
import 'package:common/common/widget/settings/settings_screen.dart';
import 'package:common/common/widget/stats/stats_section.dart';
import 'package:common/common/widget/support/support_screen.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/common/widget/top_bar.dart';
import 'package:common/common/widget/with_top_bar.dart';
import 'package:common/core/core.dart';
import 'package:common/dragon/dialog.dart';
import 'package:common/dragon/journal/controller.dart';
import 'package:common/dragon/route.dart';
import 'package:common/dragon/support/support_unread.dart';
import 'package:common/family/widget/device/device_screen.dart';
import 'package:common/family/widget/filters_section.dart';
import 'package:common/family/widget/home/home_screen.dart';
import 'package:common/family/widget/stats_detail_section.dart';
import 'package:common/platform/custom/custom.dart';
import 'package:flutter/material.dart';

enum Paths {
  home("/", false),
  device("/device", false),
  deviceFilters("/device/filters", true),
  deviceStats("/device/stats", true),
  deviceStatsDetail("/device/stats/detail", true),
  settings("/settings", false),
  settingsExceptions("/settings/exceptions", true),
  support("/support", false);

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
  late final journal = dep<JournalController>();
  late final _custom = dep<CustomStore>();

  static late bool isTabletMode;

  static Function(Paths, Object?) openInTablet = (_, __) {};
  static Function(Paths? path) onNavigated = (_) {};

  static open(Paths path, {Object? arguments}) async {
    onNavigated(path);
    if (isTabletMode && path.openInTablet) {
      openInTablet(path, arguments);
      return;
    }

    final ctrl = dep<TopBarController>();
    ctrl.navigatorKey.currentState!.pushNamed(path.path, arguments: arguments);
  }

  StandardRoute generateRoute(BuildContext context, RouteSettings settings,
      {Widget? homeContent}) {
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
          child: StatsSection(deviceTag: device.device.deviceTag),
        ),
      );
    }

    if (settings.name == Paths.deviceFilters.path) {
      final device = settings.arguments as FamilyDevice;

      return StandardRoute(
        settings: settings,
        builder: (context) => WithTopBar(
          title: "family stats label blocklists".i18n,
          child: FiltersSection(profileId: device.profile.profileId),
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

    if (settings.name == Paths.support.path) {
      return StandardRoute(
          settings: settings, builder: (context) => const SupportScreen());
    }

    return StandardRoute(
        settings: settings,
        builder: (context) => homeContent ?? const HomeScreen());
  }

  Widget? _getStatsAction(BuildContext context, DeviceTag tag) {
    return CommonClickable(
        onTap: () {
          showStatsFilterDialog(context, onConfirm: (filter) {
            journal.filter = filter;
            journal.fetch(tag, Markers.userTap);
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
}

class NavigationPopObserver extends NavigatorObserver {
  late final _journal = dep<JournalController>();
  late final _unread = dep<SupportUnreadController>();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is StandardRoute && previousRoute is StandardRoute) {
      final r = route.settings;
      final p = previousRoute.settings;

      // Resets journal filter when leaving device section
      if (r.name == Paths.device.path && p.name == Paths.home.path) {
        _journal.resetFilter();
      }

      // Resets some flag when leaving support section
      // TODO: this needs rework and merging with StageStore
      if (r.name == Paths.support.path) {
        _unread.wentBackFromSupport();
      }
    }
  }
}
