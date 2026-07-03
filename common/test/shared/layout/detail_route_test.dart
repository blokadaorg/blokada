import 'package:common/src/app_variants/family/module/device_v3/device.dart';
import 'package:common/src/app_variants/family/module/family/family.dart';
import 'package:common/src/app_variants/family/module/profile/profile.dart';
import 'package:common/src/app_variants/family/module/stats/stats.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/features/journal/domain/journal.dart';
import 'package:common/src/features/stats/ui/domain_detail_section.dart';
import 'package:common/src/features/stats/ui/stats_detail_section.dart';
import 'package:common/src/features/stats/ui/stats_section.dart';
import 'package:common/src/shared/layout/detail_route.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// Pins the registry against the strings and widgets the old duplicated
// code paths produced (generateRoute, TopBarController.didPush, and the
// per-screen tablet _buildForPath switches), so consolidating them is
// provably behavior-preserving.
void main() {
  setUp(() {
    Core.act = ActScreenplay(ActScenario.test, Flavor.v6, PlatformType.iOS);
  });

  FamilyDevice device({bool thisDevice = false}) {
    return FamilyDevice(
      device: JsonDevice(
        deviceTag: "example-tag",
        alias: "Example Phone",
        mode: JsonDeviceMode.on,
        retention: "24h",
        profileId: "example-profile",
      ),
      profile: JsonProfile(
        profileId: "example-profile",
        alias: "Child (parent)",
        lists: [],
        safeSearch: false,
      ),
      stats: UiStats.empty(),
      thisDevice: thisDevice,
      linked: false,
    );
  }

  UiJournalMainEntry mainEntry() {
    return UiJournalMainEntry(
      domainName: "tracker.example.com",
      requests: 5,
      action: UiJournalAction.block,
      listId: "list1",
    );
  }

  UiJournalEntry journalEntry() {
    return UiJournalEntry(
      deviceName: "Example Phone",
      domainName: "ads.example.com",
      action: UiJournalAction.block,
      listId: "list1",
      profileId: null,
      timestamp: DateTime(2026, 1, 1),
      requests: 3,
    );
  }

  Future<BuildContext> contextOf(WidgetTester tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    }));
    return ctx;
  }

  group("titles", () {
    test("v6 titles match the legacy top-bar strings", () {
      final routes = DetailRoutes();
      expect(routes.resolve(Paths.deviceStats)!.title(null), "activity section header".i18n);
      expect(routes.resolve(Paths.deviceFilters)!.title(null),
          "family stats label blocklists".i18n);
      expect(routes.resolve(Paths.deviceStatsDetail)!.title(null),
          "domain details section header".i18n);
      expect(routes.resolve(Paths.settings)!.title(null), "main tab settings".i18n);
      expect(routes.resolve(Paths.settingsExceptions)!.title(null), "family stats title".i18n);
      expect(routes.resolve(Paths.settingsRetention)!.title(null),
          "activity section header".i18n);
      expect(routes.resolve(Paths.settingsVpnDevices)!.title(null),
          "web vpn devices header".i18n);
      expect(routes.resolve(Paths.settingsVpnBypass)!.title(null),
          "bypass section header".i18n);
      expect(routes.resolve(Paths.support)!.title(null), "support action chat".i18n);
      expect(routes.resolve(Paths.activity)!.title(null), "main tab activity".i18n);
      expect(routes.resolve(Paths.privacyPulse)!.title(null),
          "privacy pulse section header".i18n);
      expect(routes.resolve(Paths.advanced)!.title(null), "main tab advanced".i18n);
    });

    test("family flavor swaps the flavor-dependent titles", () {
      Core.act = ActScreenplay(ActScenario.test, Flavor.family, PlatformType.iOS);
      final routes = DetailRoutes();
      expect(routes.resolve(Paths.settings)!.title(null), "account action my account".i18n);
      expect(routes.resolve(Paths.deviceStatsDetail)!.title(null),
          "family device title details".i18n);
    });

    test("device title uses the device display name", () {
      final routes = DetailRoutes();
      expect(routes.resolve(Paths.device)!.title(device()), "Example Phone");
      expect(routes.resolve(Paths.device)!.title(device(thisDevice: true)),
          "app settings section header".i18n);
    });
  });

  group("resolveByName", () {
    test("maps route names to entries and unknown names to null", () {
      final routes = DetailRoutes();
      expect(routes.resolveByName(Paths.settingsExceptions.path)!.path,
          Paths.settingsExceptions);
      expect(routes.resolveByName("/nonexistent"), isNull);
      expect(routes.resolveByName(null), isNull);
    });
  });

  group("bodies", () {
    test("detail paths have bodies, container screens are title-only", () {
      final routes = DetailRoutes();
      const detailPaths = [
        Paths.deviceStats,
        Paths.deviceFilters,
        Paths.deviceStatsDetail,
        Paths.settingsExceptions,
        Paths.settingsRetention,
        Paths.settingsVpnDevices,
        Paths.settingsVpnBypass,
        Paths.support,
      ];
      for (final path in detailPaths) {
        expect(routes.resolve(path)!.body, isNotNull, reason: "$path");
      }
      const containerPaths = [
        Paths.device,
        Paths.settings,
        Paths.activity,
        Paths.privacyPulse,
        Paths.advanced,
      ];
      for (final path in containerPaths) {
        expect(routes.resolve(path)!.body, isNull, reason: "$path");
      }
      // Dead entry, never navigated to; deleted in cleanup.
      expect(routes.resolve(Paths.settingsAccount), isNull);
      expect(routes.resolve(Paths.home), isNull);
    });

    testWidgets("deviceStats body reads the device tag from arguments", (tester) async {
      final routes = DetailRoutes();
      final context = await contextOf(tester);
      final body = routes.resolve(Paths.deviceStats)!.body!(context, device());
      expect(body, isA<StatsSection>());
      expect((body as StatsSection).deviceTag, "example-tag");
      final pane = routes.resolve(Paths.deviceStats)!.buildPane(context, device());
      expect((pane as StatsSection).primary, isFalse);
    });

    testWidgets("deviceStatsDetail with Map args builds DomainDetailSection with parsed fields",
        (tester) async {
      final routes = DetailRoutes();
      final context = await contextOf(tester);
      final entry = mainEntry();
      final body = routes.resolve(Paths.deviceStatsDetail)!.body!(context, {
        'mainEntry': entry,
        'level': 3,
        'domain': "sub.tracker.example.com",
        'fetchToplist': false,
        'showToplistSection': true,
        'showRecentSection': false,
        'range': "1w",
      });
      expect(body, isA<DomainDetailSection>());
      final section = body as DomainDetailSection;
      expect(section.entry, entry);
      expect(section.level, 3);
      expect(section.domain, "sub.tracker.example.com");
      expect(section.fetchToplist, isFalse);
      expect(section.showToplistSection, isTrue);
      expect(section.showRecentSection, isFalse);
      expect(section.range, "1w");
    });

    testWidgets("deviceStatsDetail with minimal Map args applies the legacy defaults",
        (tester) async {
      final routes = DetailRoutes();
      final context = await contextOf(tester);
      final entry = mainEntry();
      final section = routes.resolve(Paths.deviceStatsDetail)!.body!(
          context, {'mainEntry': entry}) as DomainDetailSection;
      expect(section.level, 2);
      expect(section.domain, entry.domainName);
      expect(section.fetchToplist, isTrue);
      expect(section.range, "24h");
    });

    testWidgets("deviceStatsDetail with a journal entry converts it for the pushed route",
        (tester) async {
      final routes = DetailRoutes();
      final context = await contextOf(tester);
      final entry = journalEntry();
      final section = routes.resolve(Paths.deviceStatsDetail)!.body!(context, entry)
          as DomainDetailSection;
      expect(section.entry.domainName, entry.domainName);
      expect(section.entry.requests, entry.requests);
      expect(section.entry.action, entry.action);
      expect(section.entry.listId, entry.listId);
      expect(section.level, 2);
      expect(section.domain, entry.domainName);
      expect(section.fetchToplist, isFalse);
    });

    testWidgets("deviceStatsDetail pane keeps the journal-entry divergence", (tester) async {
      final routes = DetailRoutes();
      final context = await contextOf(tester);
      final pane = routes.resolve(Paths.deviceStatsDetail)!.buildPane(context, journalEntry());
      expect(pane, isA<StatsDetailSection>());
      expect((pane as StatsDetailSection).primary, isFalse);
      // Map args (toplist navigation) keep DomainDetailSection in the pane too.
      final mapPane = routes
          .resolve(Paths.deviceStatsDetail)!
          .buildPane(context, {'mainEntry': mainEntry()});
      expect(mapPane, isA<DomainDetailSection>());
    });
  });
}
