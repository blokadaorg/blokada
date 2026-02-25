import 'package:common/src/shared/ui/dialog.dart';
import 'package:common/src/features/customlist/domain/customlist.dart';
import 'package:common/src/features/journal/domain/journal.dart';
import 'package:common/src/features/support/domain/support.dart';
import 'package:common/src/shared/route.dart';
import 'package:common/src/shared/ui/common_clickable.dart';
import 'package:common/src/features/settings/ui/exceptions_section.dart';
import 'package:common/src/features/settings/ui/retention_section.dart';
import 'package:common/src/features/settings/ui/settings_screen.dart';
import 'package:common/src/features/stats/ui/domain_detail_section.dart';
import 'package:common/src/features/stats/ui/top_domains.dart';
import 'package:common/src/features/stats/ui/stats_filter.dart';
import 'package:common/src/features/stats/ui/stats_section.dart';
import 'package:common/src/features/support/ui/support_section.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/shared/ui/top_bar.dart';
import 'package:common/src/shared/ui/with_top_bar.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/app_variants/family/module/device_v3/device.dart';
import 'package:common/src/app_variants/family/module/family/family.dart';
import 'package:common/src/app_variants/family/widget/device/device_screen.dart';
import 'package:common/src/app_variants/family/widget/filters_section.dart';
import 'package:common/src/platform/stage/stage.dart';
import 'package:common/src/features/plus/ui/vpn_bypass_dialog.dart';
import 'package:common/src/features/plus/ui/vpn_bypass_section.dart';
import 'package:common/src/features/plus/ui/vpn_devices_section.dart';
import 'package:common/src/app_variants/v6/widget/activity_screen.dart';
import 'package:common/src/app_variants/v6/widget/advanced_screen.dart';
import 'package:common/src/app_variants/v6/widget/privacy_pulse_screen.dart';
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
  late final _custom = Core.get<CustomlistActor>();
  late final _support = Core.get<SupportActor>();
  late final _bypass = Core.get<BypassAddDialog>();

  static late bool isTabletMode;

  static Function(Paths, Object?) openInTablet = (_, __) {};
  static Function(Paths? path) onNavigated = (_) {};
  // Track last navigated path directly from Navigation; StageStore is being phased out and
  // should not be treated as the source of truth for current UI route.
  static Paths? lastPath;

  static open(Paths path, {Object? arguments}) async {
    onNavigated(path);
    lastPath = path;
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
          settings: settings, builder: (context) => DeviceScreen(tag: device.device.deviceTag));
    }

    if (settings.name == Paths.deviceStats.path) {
      final device = settings.arguments as FamilyDevice;

      return StandardRoute(
        settings: settings,
        builder: (context) => WithTopBar(
          title: "activity section header".i18n,
          topBarTrailing: _getStatsAction(context, device.device.deviceTag),
          child: StatsSection(deviceTag: device.device.deviceTag, isHeader: false),
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
      // Check if this is a Map argument (from toplist or subdomain navigation)
      if (settings.arguments is Map) {
        final args = settings.arguments as Map;
        final mainEntry = args['mainEntry'] as UiJournalMainEntry;
        final level = args['level'] as int? ?? 2;
        final domain = args['domain'] as String? ?? mainEntry.domainName;
        final fetchToplist = args['fetchToplist'] as bool? ?? true;
        final showToplistSection = args['showToplistSection'] as bool?;
        final showRecentSection = args['showRecentSection'] as bool?;

        final range = args['range'] as String? ?? "24h";

        return StandardRoute(
          settings: settings,
          builder: (context) => WithTopBar(
            title: Core.act.isFamily
                ? "family device title details".i18n
                : "domain details section header".i18n,
            child: DomainDetailSection(
              entry: mainEntry,
              level: level,
              domain: domain,
              fetchToplist: fetchToplist,
              showToplistSection: showToplistSection,
              showRecentSection: showRecentSection,
              range: range,
            ),
          ),
        );
      } else {
        // Normal entry - convert to UiJournalMainEntry and use DomainDetailSection
        final entry = settings.arguments as UiJournalEntry;
        final mainEntry = UiJournalMainEntry(
          domainName: entry.domainName,
          requests: entry.requests,
          action: entry.action,
          listId: entry.listId,
        );

        return StandardRoute(
          settings: settings,
          builder: (context) => WithTopBar(
            title: Core.act.isFamily
                ? "family device title details".i18n
                : "domain details section header".i18n,
            child: DomainDetailSection(
              entry: mainEntry,
              level: 2, // Start at level 2 (subdomains)
              domain: entry.domainName,
              fetchToplist: false, // Don't fetch toplists for journal entries
            ),
          ),
        );
      }
    }

    if (settings.name == Paths.settings.path) {
      return StandardRoute(settings: settings, builder: (context) => const SettingsScreen());
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

    if (settings.name == Paths.settingsVpnBypass.path) {
      return StandardRoute(
        settings: settings,
        builder: (context) => WithTopBar(
          title: "bypass section header".i18n,
          topBarTrailing: _bypass.getBypassAction(context),
          child: const VpnBypassSection(),
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
          showAddExceptionDialog(context, onConfirm: (entry, blocked) {
            final trimmed = entry.trim();
            if (trimmed.isEmpty) return;

            final isWildcard = trimmed.startsWith("*.");
            final domain = isWildcard ? trimmed.substring(2) : trimmed;
            if (domain.isEmpty) return;

            log(Markers.userTap).trace("addCustom", (m) async {
              await _custom.addOrRemove(domain, isWildcard, m, gotBlocked: !blocked);
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
