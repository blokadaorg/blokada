import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:common/src/app_variants/v6/widget/freemium/weekly_refresh_sheet.dart';
import 'package:common/src/app_variants/v6/widget/home_screen.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/features/api/domain/api.dart' as api;
import 'package:common/src/features/modal/domain/modal.dart';
import 'package:common/src/features/onboard/ui/onboard_screen.dart';
import 'package:common/src/features/plus/domain/gateway/gateway.dart';
import 'package:common/src/features/plus/domain/plus.dart';
import 'package:common/src/features/private_dns/domain/private_dns_setup.dart';
import 'package:common/src/features/private_dns/ui/private_dns_sheet_android.dart';
import 'package:common/src/features/stats/ui/domain_detail_section.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/platform/account/api.dart';
import 'package:common/src/platform/app/channel.pg.dart';
import 'package:common/src/platform/perm/perm.dart';
import 'package:common/src/shared/automation/ids.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:common/src/shared/ui/action_sheet.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart';

import '../features/private_dns/private_dns_setup_test.dart';
import '../golden/fixtures.dart';
import '../golden/golden_tools.dart';

/// Phones the screens must fit, as physical pixels and density: a small
/// 360×640 phone and the 1080×2400 one the goldens use (411×914 logical).
const _phones = {
  'small': (Size(720, 1280), 2.0),
  'large': (phoneSize, phoneDpr),
};

/// System text sizes: the default and the large sizes the app used to clamp
/// away, up to about the largest iOS accessibility size (Android stops at 2.0).
const _scales = [1.0, 1.5, 2.0, 3.0];

/// Full reports of the errors thrown since the last check. takeException keeps
/// only the first error's summary, without the widget that caused it.
final _reported = <FlutterErrorDetails>[];

/// Records each reported error, then hands it to the test binding as usual.
void _recordErrors() {
  final binding = FlutterError.onError;
  FlutterError.onError = (details) {
    _reported.add(details);
    binding?.call(details);
  };
  addTearDown(() => FlutterError.onError = binding);
}

/// Layout overflows throw in tests; any exception means the screen broke.
void _expectNoOverflow(WidgetTester tester) {
  final reports = _reported.map((d) => d.toString()).join('\n');
  _reported.clear();
  expect(tester.takeException(), isNull, reason: reports);
}

Finder _byId(String id) =>
    find.byWidgetPredicate((w) => w is Semantics && w.properties.identifier == id);

/// Scrolls every vertical list to its end, so rows built lazily below the
/// fold are laid out (and checked) too.
Future<void> _scrollThrough(WidgetTester tester) async {
  final lists = tester
      .stateList<ScrollableState>(find.byType(Scrollable))
      .where((s) => s.position.axis == Axis.vertical)
      .toList();
  for (final list in lists) {
    for (var page = 0; page < 30; page++) {
      if (!list.mounted) break;
      final position = list.position;
      if (position.pixels >= position.maxScrollExtent) break;
      position.jumpTo(min(position.pixels + position.viewportDimension, position.maxScrollExtent));
      await tester.pump();
    }
  }
}

/// Favicons load through a disk cache backed by plugins tests don't have;
/// every load fails, so domain details show their fallback icon.
class _OfflineFaviconCache implements BaseCacheManager {
  @override
  Stream<FileResponse> getFileStream(String url,
          {String? key, Map<String, String>? headers, bool withProgress = false}) =>
      Stream.error(HttpExceptionWithStatus(404, 'No network in tests', uri: Uri.parse(url)));

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('_OfflineFaviconCache: ${invocation.memberName}');
}

Future<void> _seedAccount(WidgetTester tester, String type,
    {Map<String, dynamic>? attributes}) async {
  await tester.runAsync(() => Core.get<api.AccountId>().change(Markers.testing, 'testaccount01'));
  runInAction(() {
    Core.get<AccountStore>().account = AccountState(
      'testaccount01',
      JsonAccount(
        id: 'testaccount01',
        activeUntil: type == 'libre' ? null : '2099-01-01T00:00:00Z',
        active: type != 'libre',
        type: type,
        attributes: attributes,
      ),
    );
  });
}

Future<void> _seedPlus(WidgetTester tester) async {
  await _seedAccount(tester, 'plus');
  seedDevice();
  seedStats();
  seedAppStatus(AppStatus.activatedPlus);
  await tester.runAsync(() async {
    await Core.get<PlusEnabledValue>().change(Markers.testing, true);
    await Core.get<VpnEnabledValue>().change(Markers.testing, true);
    await Core.get<CurrentGatewayValue>().change(
        Markers.testing,
        Gateway('key', 'europe-west1', 'frankfurt-am-main', 10, '10.0.0.1', '::1', 51820,
            'DE'));
  });
}

Future<void> _seedFreemium(WidgetTester tester) async {
  await _seedAccount(tester, 'libre', attributes: {'freemium': true});
  seedDevice();
  seedAppStatus(AppStatus.activatedCloud);
}

/// Shows [builder] the way the app shows its sheets: through the modal value
/// the bottom sheet host listens to.
Future<void> _showSheet(WidgetTester tester, Modal modal, WidgetBuilder builder) async {
  await tester.runAsync(() async {
    await Core.get<CurrentModalValue>().change(Markers.testing, modal);
    await Core.get<CurrentModalWidgetValue>().change(Markers.testing, builder);
  });
  await settleScreen(tester);
}

void main() {
  // Each test file runs in its own isolate, so this needs no restoring; reading
  // the default first would build the real cache, which needs path_provider.
  setUpAll(() => CachedNetworkImageProvider.defaultCacheManager = _OfflineFaviconCache());

  for (final MapEntry(key: phone, value: (physicalSize, dpr)) in _phones.entries) {
    for (final scale in _scales) {
      group('$phone phone, text ${scale}x', () {
        Future<void> pump(WidgetTester tester,
            {Paths? path,
            Widget? content,
            TargetPlatform platform = TargetPlatform.android}) async {
          _recordErrors();
          await pumpShell(tester,
              path: path,
              content: content,
              platform: platform,
              physicalSize: physicalSize,
              devicePixelRatio: dpr,
              textScale: scale);
          _expectNoOverflow(tester);
        }

        Future<void> finish(WidgetTester tester) async {
          await _scrollThrough(tester);
          _expectNoOverflow(tester);
          debugDefaultTargetPlatformOverride = null;
          await unmountShell(tester);
        }

        testWidgets('home inactive', (tester) async {
          await bootModules(tester);
          await seedCloudAccount(tester);
          seedAppStatus(AppStatus.deactivated);
          await pump(tester);
          await finish(tester);
        });

        testWidgets('home active, with the pause sheet', (tester) async {
          await bootModules(tester);
          await seedCloudAccount(tester);
          seedDevice();
          seedStats();
          seedAppStatus(AppStatus.activatedCloud);
          await pump(tester);

          showPauseActionSheet(tester.element(find.byType(V6HomeScreen)), onSelected: (_) {});
          await tester.pumpAndSettle();
          expect(_byId(AutomationIds.powerActionTurnOff), findsOneWidget);
          _expectNoOverflow(tester);
          await finish(tester);
        });

        testWidgets('home with Plus location', (tester) async {
          await bootModules(tester);
          await _seedPlus(tester);
          await pump(tester);
          expect(find.textContaining('Frankfurt Am Main'), findsWidgets);
          await finish(tester);
        });

        testWidgets('pause sheet on iOS', (tester) async {
          await bootModules(tester, platform: PlatformType.iOS);
          await seedCloudAccount(tester);
          seedDevice();
          seedAppStatus(AppStatus.activatedCloud);
          await pump(tester, platform: TargetPlatform.iOS);

          showPauseActionSheet(tester.element(find.byType(V6HomeScreen)), onSelected: (_) {});
          await tester.pumpAndSettle();
          expect(_byId(AutomationIds.powerActionTurnOff), findsOneWidget);
          _expectNoOverflow(tester);
          await finish(tester);
        });

        testWidgets('onboarding', (tester) async {
          await bootModules(tester);
          await pump(tester, content: const OnboardingScreen());
          await finish(tester);
        });

        testWidgets('settings', (tester) async {
          await bootModules(tester);
          await seedCloudAccount(tester);
          seedAppStatus(AppStatus.activatedCloud);
          await pump(tester, path: Paths.settings);
          await finish(tester);
        });

        testWidgets('blocklists', (tester) async {
          await bootModules(tester);
          await seedCloudAccount(tester);
          await seedBlocklists(tester);
          seedAppStatus(AppStatus.activatedCloud);
          await pump(tester, path: Paths.advanced);
          await finish(tester);
        });

        testWidgets('privacy pulse', (tester) async {
          await bootModules(tester);
          await seedCloudAccount(tester);
          seedDevice();
          seedStats();
          seedAppStatus(AppStatus.activatedCloud);
          await pump(tester, path: Paths.privacyPulse);
          await finish(tester);
        });

        testWidgets('activity list and detail', (tester) async {
          await bootModules(tester);
          await seedCloudAccount(tester);
          seedDevice();
          seedAppStatus(AppStatus.activatedCloud);
          await pump(tester, path: Paths.activity);
          await _scrollThrough(tester);
          _expectNoOverflow(tester);

          for (final list in tester.stateList<ScrollableState>(find.byType(Scrollable))) {
            list.position.jumpTo(0);
          }
          await tester.pump();
          await tester.tap(find.text('doubleclick.net').first);
          await settleScreen(tester);
          expect(find.byType(DomainDetailSection), findsOneWidget);
          _expectNoOverflow(tester);
          await finish(tester);
        });

        testWidgets('Private DNS sheet', (tester) async {
          await bootModules(tester);
          await seedCloudAccount(tester);
          seedDevice();
          seedAppStatus(AppStatus.deactivated);
          await pump(tester);
          final channel = FakeDnsChannel(dnsState(null));
          await _showSheet(
            tester,
            Modal.onboardPrivateDns,
            (_) => PrivateDnsSheetAndroid(
              manufacturer: 'Samsung',
              successDelay: Duration.zero,
              copiedBeforeSettingsDelay: Duration.zero,
              verifier: PrivateDnsSetupVerifier(
                channel: channel,
                check: FakeOwnerCheck(const ['cloud']),
                probeDelay: Duration.zero,
              ),
            ),
          );
          expect(find.byType(PrivateDnsSheetAndroid), findsOneWidget);
          _expectNoOverflow(tester);
          await finish(tester);
        });

        // Freemium (iOS only) puts paywall entry points over the tabs.
        for (final (name, path) in [
          ('home', null),
          ('privacy pulse', Paths.privacyPulse),
          ('activity', Paths.activity),
          ('blocklists', Paths.advanced),
        ]) {
          testWidgets('freemium $name', (tester) async {
            await bootModules(tester, platform: PlatformType.iOS);
            await _seedFreemium(tester);
            seedStats();
            await pump(tester, path: path, platform: TargetPlatform.iOS);
            await finish(tester);
          });
        }

        testWidgets('freemium weekly refresh sheet', (tester) async {
          await bootModules(tester, platform: PlatformType.iOS);
          await _seedFreemium(tester);
          await pump(tester, platform: TargetPlatform.iOS);
          await _showSheet(tester, Modal.weeklyRefresh, (_) => const WeeklyRefreshSheetIos());
          expect(find.byType(WeeklyRefreshSheetIos), findsOneWidget);
          _expectNoOverflow(tester);
          await finish(tester);
        });
      });
    }
  }
}
