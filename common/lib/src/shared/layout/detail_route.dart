import 'package:common/src/app_variants/family/module/family/family.dart';
import 'package:common/src/app_variants/family/widget/filters_section.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/features/customlist/domain/customlist.dart';
import 'package:common/src/features/journal/domain/journal.dart';
import 'package:common/src/features/plus/ui/vpn_bypass_dialog.dart';
import 'package:common/src/features/plus/ui/vpn_bypass_section.dart';
import 'package:common/src/features/plus/ui/vpn_devices_section.dart';
import 'package:common/src/features/settings/ui/exceptions_section.dart';
import 'package:common/src/features/settings/ui/retention_section.dart';
import 'package:common/src/features/stats/ui/domain_detail_section.dart';
import 'package:common/src/features/stats/ui/stats_detail_section.dart';
import 'package:common/src/features/stats/ui/stats_filter.dart';
import 'package:common/src/features/stats/ui/stats_section.dart';
import 'package:common/src/features/support/domain/support.dart';
import 'package:common/src/features/support/ui/support_section.dart';
import 'package:common/src/shared/automation/ids.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:common/src/shared/ui/common_clickable.dart';
import 'package:common/src/shared/ui/dialog.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/material.dart';

/// Domain shown by a deviceStatsDetail selection, so master list rows can
/// highlight the entry whose detail pane is open. Mirrors the argument
/// shapes DetailRoutes' domain-detail builder accepts.
String? domainOfDetailArguments(Object? arguments) {
  if (arguments is Map) {
    final domain = arguments['domain'];
    if (domain is String) return domain;
    final mainEntry = arguments['mainEntry'];
    if (mainEntry is UiJournalMainEntry) return mainEntry.domainName;
    return null;
  }
  if (arguments is UiJournalEntry) return arguments.domainName;
  return null;
}

/// One registry entry per navigable [Paths] value.
///
/// Exists so a route's title, body and top-bar action are defined once.
/// They used to be duplicated across `Navigation.generateRoute` (phone
/// push), `TopBarController.didPush` (title stack), and each two-pane
/// screen's `_buildForPath` switch (tablet detail pane), which drifted —
/// e.g. the tablet Settings copy of the Add-exception action lost its
/// automation Semantics.
class DetailRoute {
  final Paths path;

  /// Top-bar title, resolved lazily so flavor branching and i18n happen at
  /// navigation time, matching the old call sites.
  final String Function(Object? arguments) title;

  /// Bare section for a pushed full-screen route (callers wrap it in
  /// WithTopBar). Null for container screens that own their route widget
  /// (home tabs, settings root) — those stay in `generateRoute`.
  final Widget Function(BuildContext context, Object? arguments)? body;

  /// Detail-pane override where the pane historically diverged from the
  /// pushed route (e.g. journal entries render StatsDetailSection in the
  /// pane but DomainDetailSection when pushed). Defaults to [body].
  final Widget Function(BuildContext context, Object? arguments)? paneBody;

  /// Top-bar trailing action for this route, if any.
  final Widget? Function(BuildContext context, Object? arguments)? trailing;

  const DetailRoute({
    required this.path,
    required this.title,
    this.body,
    this.paneBody,
    this.trailing,
  });

  Widget buildPane(BuildContext context, Object? arguments) =>
      (paneBody ?? body)!(context, arguments);
}

/// DI-registered lookup (`Core.get<DetailRoutes>()`) consumed by
/// `Navigation.generateRoute`, `TopBarController.didPush`, and the tablet
/// detail pane.
class DetailRoutes with Logging {
  late final _filter = Core.get<JournalFilterValue>();
  late final _custom = Core.get<CustomlistActor>();
  late final _support = Core.get<SupportActor>();
  late final _bypass = Core.get<BypassAddDialog>();

  late final Map<Paths, DetailRoute> _routes = Map.fromEntries(<DetailRoute>[
    DetailRoute(
      path: Paths.device,
      title: (args) => (args as FamilyDevice).displayName,
    ),
    DetailRoute(
      path: Paths.deviceStats,
      title: (_) => "activity section header".i18n,
      body: (context, args) => StatsSection(
          deviceTag: (args as FamilyDevice).device.deviceTag, isHeader: false),
      trailing: (context, args) => statsFilterAction(context),
    ),
    DetailRoute(
      path: Paths.deviceFilters,
      title: (_) => "family stats label blocklists".i18n,
      body: (context, args) => FamilyFiltersSection(
          profileId: (args as FamilyDevice).profile.profileId),
    ),
    DetailRoute(
      path: Paths.deviceStatsDetail,
      title: (_) => Core.act.isFamily
          ? "family device title details".i18n
          : "domain details section header".i18n,
      body: (context, args) => _domainDetail(args, pane: false),
      paneBody: (context, args) => _domainDetail(args, pane: true),
    ),
    DetailRoute(
      path: Paths.settings,
      title: (_) => Core.act.isFamily
          ? "account action my account".i18n
          : "main tab settings".i18n,
    ),
    DetailRoute(
      path: Paths.settingsExceptions,
      title: (_) => "family stats title".i18n,
      body: (context, args) => const ExceptionsSection(),
      trailing: (context, args) => _addExceptionAction(context),
    ),
    DetailRoute(
      path: Paths.settingsRetention,
      title: (_) => "activity section header".i18n,
      body: (context, args) => const RetentionSection(),
    ),
    DetailRoute(
      path: Paths.settingsVpnDevices,
      title: (_) => "web vpn devices header".i18n,
      body: (context, args) => const VpnDevicesSection(),
    ),
    DetailRoute(
      path: Paths.settingsVpnBypass,
      title: (_) => "bypass section header".i18n,
      body: (context, args) => const VpnBypassSection(),
      trailing: (context, args) => _bypass.getBypassAction(context),
    ),
    DetailRoute(
      // The end-chat trailing pops the current route, so Support must only
      // ever render as a pushed route — never include it in a host's
      // detailPaths or the pop would dismiss the whole two-pane screen.
      path: Paths.support,
      title: (_) => "support action chat".i18n,
      body: (context, args) => const SupportSection(),
      trailing: (context, args) => _endSupportAction(context),
    ),
    DetailRoute(
      path: Paths.activity,
      title: (_) => "main tab activity".i18n,
    ),
    DetailRoute(
      path: Paths.privacyPulse,
      title: (_) => "privacy pulse section header".i18n,
    ),
    DetailRoute(
      path: Paths.advanced,
      title: (_) => "main tab advanced".i18n,
    ),
  ].map((route) => MapEntry(route.path, route)));

  DetailRoute? resolve(Paths path) => _routes[path];

  DetailRoute? resolveByName(String? routeName) {
    if (routeName == null) return null;
    for (final path in Paths.values) {
      if (path.path == routeName) return resolve(path);
    }
    return null;
  }

  /// Shared domain-detail construction for pushed routes and the pane.
  /// Map arguments come from toplist/subdomain navigation; a plain journal
  /// entry historically renders StatsDetailSection in the pane but a
  /// converted DomainDetailSection when pushed — preserved until product
  /// decides to consolidate.
  Widget _domainDetail(Object? arguments, {required bool pane}) {
    if (arguments is Map) {
      final mainEntry = arguments['mainEntry'] as UiJournalMainEntry;
      return DomainDetailSection(
        entry: mainEntry,
        level: arguments['level'] as int? ?? 2,
        domain: arguments['domain'] as String? ?? mainEntry.domainName,
        fetchToplist: arguments['fetchToplist'] as bool? ?? true,
        showToplistSection: arguments['showToplistSection'] as bool?,
        showRecentSection: arguments['showRecentSection'] as bool?,
        range: arguments['range'] as String? ?? "24h",
      );
    }

    final entry = arguments as UiJournalEntry;
    if (pane) return StatsDetailSection(entry: entry);

    return DomainDetailSection(
      entry: UiJournalMainEntry(
        domainName: entry.domainName,
        requests: entry.requests,
        action: entry.action,
        listId: entry.listId,
      ),
      level: 2, // Start at level 2 (subdomains)
      domain: entry.domainName,
      fetchToplist: false, // Don't fetch toplists for journal entries
    );
  }

  /// Journal search/filter top-bar action. Public because ActivityScreen
  /// also shows it as its host-level action for the master journal list.
  Widget statsFilterAction(BuildContext context) {
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

  Widget _addExceptionAction(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        identifier: AutomationIds.exceptionAddButton,
        button: true,
        child: CommonClickable(
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
          ),
        ),
      ),
    );
  }

  Widget _endSupportAction(BuildContext context) {
    return CommonClickable(
        onTap: () {
          Navigator.of(context).pop();
          _support.clearSession(Markers.userTap);
        },
        child: Text("support action end".i18n,
            style: const TextStyle(color: Colors.red, fontSize: 17)));
  }
}
