import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

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
import 'package:common/src/features/rate/ui/rate_screen.dart';
import 'package:common/src/features/safari/ui/safari_onboard_yt_sheet.dart';
import 'package:common/src/features/stats/ui/domain_detail_section.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/platform/account/api.dart';
import 'package:common/src/platform/app/channel.pg.dart';
import 'package:common/src/platform/perm/perm.dart';
import 'package:common/src/shared/automation/ids.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:common/src/shared/ui/minicard/header.dart';
import 'package:common/src/shared/ui/action_sheet.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart';

import '../features/private_dns/private_dns_setup_test.dart';
import '../golden/fixtures.dart';
import '../golden/golden_tools.dart';

/// Phones the screens must fit, as physical pixels and density: a small
/// 360×640 phone and the 1080×2400 one the goldens use (411×914 logical).
const _phones = {'small': (Size(720, 1280), 2.0), 'large': (phoneSize, phoneDpr)};

/// System text sizes: the smallest iOS size, the default, the largest
/// non-accessibility iOS size, and the accessibility sizes up to the largest
/// one on iOS (Android stops at 2.0).
const _scales = [0.8, 1.0, 1.35, 2.0, 3.1];

/// English, and German for its long words and labels.
const _locales = [Locale('en', 'US'), Locale('de', 'DE')];

/// Set to a directory to save a PNG of each screen as first shown (before
/// scrolling), for a visual check across sizes.
final _shotsDir = Platform.environment['TEXT_SCALE_SHOTS'];

/// Saves the current frame as `<_shotsDir>/<name>.png` when shots are on.
Future<void> _shot(WidgetTester tester, String name) async {
  final dir = _shotsDir;
  if (dir == null) return;
  // The whole view, sheets and overlays included: the root repaint boundary
  // above the app.
  RenderObject? root = tester.renderObject(find.byType(MaterialApp).first);
  while (root!.parent != null) {
    root = root.parent;
  }
  final layer = root.debugLayer! as OffsetLayer;
  await tester.runAsync(() async {
    final image = await layer.toImage(
      root!.paintBounds,
      pixelRatio: 1 / tester.view.devicePixelRatio,
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

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

/// How far down a key action may sit, in screen heights, before reaching it
/// takes more scrolling than it should.
const _reachScreens = 1.75;

/// The action [id] is on screen, its top within [_reachScreens] screen
/// heights from the top (before scrolling).
void _expectReachable(WidgetTester tester, String id, {double screens = _reachScreens}) {
  final finder = _byId(id);
  expect(finder, findsOneWidget, reason: '$id missing');
  final height = tester.view.physicalSize.height / tester.view.devicePixelRatio;
  final top = tester.getRect(finder).top;
  expect(
    top,
    lessThan(height * screens),
    reason: '$id starts at $top, more than $screens screens of $height down',
  );
}

/// The power button is fully on the first screen.
void _expectPowerOnFirstScreen(WidgetTester tester) {
  final height = tester.view.physicalSize.height / tester.view.devicePixelRatio;
  expect(tester.getRect(_byId(AutomationIds.powerToggle)).bottom, lessThanOrEqualTo(height));
}

/// Card titles (such as Home's "Last 24h") wrap rather than being cut.
void _expectCardTitlesWhole(WidgetTester tester) {
  final titles = find.descendant(
    of: find.byType(MiniCardHeader),
    matching: find.byWidgetPredicate((w) => w is Text),
  );
  expect(titles, findsWidgets);
  for (final title in tester.widgetList<Text>(titles)) {
    expect(title.maxLines, isNull, reason: '"${title.data}" is limited to lines');
    expect(title.overflow, isNot(TextOverflow.ellipsis), reason: '"${title.data}" is cut');
  }
}

/// Home's key actions: power first, the tab buttons within reach.
void _expectHomeReachable(WidgetTester tester) {
  _expectPowerOnFirstScreen(tester);
  _expectReachable(tester, AutomationIds.homePrivacyPulse);
  _expectReachable(tester, AutomationIds.homeAdvanced);
}

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
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) => Stream.error(HttpExceptionWithStatus(404, 'No network in tests', uri: Uri.parse(url)));

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('_OfflineFaviconCache: ${invocation.memberName}');
}

Future<void> _seedAccount(
  WidgetTester tester,
  String type, {
  Map<String, dynamic>? attributes,
}) async {
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
      Gateway('key', 'europe-west1', 'frankfurt-am-main', 10, '10.0.0.1', '::1', 51820, 'DE'),
    );
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
    for (final locale in _locales) {
      for (final scale in _scales) {
        group('$phone phone, ${locale.languageCode}, text ${scale}x', () {
          Future<void> pump(
            WidgetTester tester, {
            Paths? path,
            Widget? content,
            TargetPlatform platform = TargetPlatform.android,
          }) async {
            _recordErrors();
            tester.platformDispatcher.localesTestValue = [locale];
            addTearDown(tester.platformDispatcher.clearLocalesTestValue);
            await pumpShell(
              tester,
              path: path,
              content: content,
              platform: platform,
              physicalSize: physicalSize,
              devicePixelRatio: dpr,
              textScale: scale,
            );
            _expectNoOverflow(tester);
          }

          Future<void> finish(WidgetTester tester, String name) async {
            await _shot(
              tester,
              '${name.replaceAll(' ', '_')}-$phone-${locale.languageCode}-$scale',
            );
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
            _expectHomeReachable(tester);
            await finish(tester, 'home inactive');
          });

          testWidgets('home active, with the pause sheet', (tester) async {
            await bootModules(tester);
            await seedCloudAccount(tester);
            seedDevice();
            seedStats();
            seedAppStatus(AppStatus.activatedCloud);
            await pump(tester);
            _expectHomeReachable(tester);
            _expectCardTitlesWhole(tester);

            showPauseActionSheet(tester.element(find.byType(V6HomeScreen)), onSelected: (_) {});
            await tester.pumpAndSettle();
            expect(_byId(AutomationIds.powerActionTurnOff), findsOneWidget);
            _expectNoOverflow(tester);
            await finish(tester, 'home active, with the pause sheet');
          });

          testWidgets('home with Plus location', (tester) async {
            await bootModules(tester);
            await _seedPlus(tester);
            await pump(tester);
            expect(find.textContaining('Frankfurt Am Main'), findsWidgets);
            _expectHomeReachable(tester);
            _expectCardTitlesWhole(tester);
            await finish(tester, 'home with Plus location');
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
            // Cancel stays on screen even when the actions scroll.
            _expectReachable(tester, AutomationIds.powerActionCancel, screens: 1);
            _expectNoOverflow(tester);
            await finish(tester, 'pause sheet on iOS');
          });

          testWidgets('onboarding', (tester) async {
            await bootModules(tester);
            await pump(tester, content: const OnboardingScreen());
            _expectReachable(tester, AutomationIds.onboardContinue);
            await finish(tester, 'onboarding');
          });

          testWidgets('settings', (tester) async {
            await bootModules(tester);
            await seedCloudAccount(tester);
            seedAppStatus(AppStatus.activatedCloud);
            await pump(tester, path: Paths.settings);
            await finish(tester, 'settings');
          });

          testWidgets('blocklists', (tester) async {
            await bootModules(tester);
            await seedCloudAccount(tester);
            await seedBlocklists(tester);
            seedAppStatus(AppStatus.activatedCloud);
            await pump(tester, path: Paths.advanced);
            await finish(tester, 'blocklists');
          });

          testWidgets('privacy pulse', (tester) async {
            await bootModules(tester);
            await seedCloudAccount(tester);
            seedDevice();
            seedStats();
            seedAppStatus(AppStatus.activatedCloud);
            await pump(tester, path: Paths.privacyPulse);
            await finish(tester, 'privacy pulse');
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
            await finish(tester, 'activity list and detail');
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
                verifier: PrivateDnsSetupVerifier(channel: channel),
              ),
            );
            expect(find.byType(PrivateDnsSheetAndroid), findsOneWidget);
            _expectNoOverflow(tester);
            await finish(tester, 'Private DNS sheet');
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
              if (path == null) _expectHomeReachable(tester);
              await finish(tester, 'freemium $name');
            });
          }

          testWidgets('freemium weekly refresh sheet', (tester) async {
            await bootModules(tester, platform: PlatformType.iOS);
            await _seedFreemium(tester);
            await pump(tester, platform: TargetPlatform.iOS);
            await _showSheet(tester, Modal.weeklyRefresh, (_) => const WeeklyRefreshSheetIos());
            expect(find.byType(WeeklyRefreshSheetIos), findsOneWidget);
            _expectNoOverflow(tester);
            await finish(tester, 'freemium weekly refresh sheet');
          });

          testWidgets('freemium YouTube sheet', (tester) async {
            await bootModules(tester, platform: PlatformType.iOS);
            await _seedFreemium(tester);
            await pump(tester, platform: TargetPlatform.iOS);
            await _showSheet(
              tester,
              Modal.onboardSafariYoutube,
              (_) => const SafariOnboardYtSheetIos(),
            );
            expect(find.byType(SafariOnboardYtSheetIos), findsOneWidget);
            _expectNoOverflow(tester);
            await finish(tester, 'freemium YouTube sheet');
          });

          testWidgets('rate dialog', (tester) async {
            await bootModules(tester);
            await seedCloudAccount(tester);
            await pump(tester, content: const RateScreen());
            expect(_byId(AutomationIds.rateDismiss), findsOneWidget);
            _expectReachable(tester, AutomationIds.rateDismiss);
            await finish(tester, 'rate dialog');
          });
        });
      }
    }
  }
}
