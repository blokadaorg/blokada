import 'dart:io';

import 'package:common/modules.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/features/env/domain/env.dart';
import 'package:common/src/features/plus/domain/keypair/keypair.dart';
import 'package:common/src/platform/plus/plus.dart';
import 'package:common/src/app_variants/v6/widget/main_screen.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:common/src/shared/ui/app.dart';
import 'package:common/src/shared/ui/top_bar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pixel size of the emulator the screenshots were taken on (MediumPhone, 420dpi).
const phoneSize = Size(1080, 2400);
const phoneDpr = 2.625;

bool _fontsLoaded = false;

/// Tests render text with a placeholder font unless real fonts are registered.
/// Roboto (the Android system font) and the Material icons ship with the Flutter SDK.
Future<void> loadFonts() async {
  if (_fontsLoaded) return;
  final root = Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
  final dir = Directory('$root/bin/cache/artifacts/material_fonts');

  Future<void> load(String family, Iterable<File> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(Future.value(ByteData.sublistView(await f.readAsBytes())));
    }
    await loader.load();
  }

  final all = dir.listSync().whereType<File>().toList();
  await load('Roboto', all.where((f) => f.path.contains('/Roboto-') && f.path.endsWith('.ttf')));
  await load('MaterialIcons', all.where((f) => f.path.endsWith('MaterialIcons-Regular.otf')));

  // Icon fonts from packages are registered under "packages/<name>/<family>".
  final pubCache = Platform.environment['PUB_CACHE'] ?? '${Platform.environment['HOME']}/.pub-cache';
  final cupertino = Directory('$pubCache/hosted/pub.dev')
      .listSync()
      .whereType<Directory>()
      .where((d) => d.path.contains('/cupertino_icons-'))
      .map((d) => File('${d.path}/assets/CupertinoIcons.ttf'))
      .where((f) => f.existsSync());
  if (cupertino.isNotEmpty) {
    await load('packages/cupertino_icons/CupertinoIcons', [cupertino.last]);
  }
  _fontsLoaded = true;
}

/// Boots the app's real modules in test mode (no platform channels, no backend)
/// so screens can be rendered with stores seeded by the test.
Future<void> bootModules(WidgetTester tester, {PlatformType platform = PlatformType.android}) async {
  await tester.runAsync(() async {
    await loadFonts();
    await I18nService.loadTranslations();
    await Core.di.reset();
    Core.di.allowReassignment = true;
    // PlusModule's keypair actor starts loading before PlatformPlusModule registers
    // its channel; on a device real I/O hides that race, in tests it does not.
    Core.register<KeypairChannel>(NoOpPlusChannel());
    await Modules().create(ActScreenplay(ActScenario.test, Flavor.v6, platform));
    // Actors normally start in Modules.start; settings needs the env info (app version).
    await Core.get<EnvActor>().onStart(Markers.start);
  });
}

/// Renders the real v6 shell (navigator, top bar, sheets) at phone size, opens
/// [path] the way the app does, and compares the result with `goldens/<name>.png`.
Future<void> expectScreen(WidgetTester tester, String name, {Paths? path}) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  tester.view.physicalSize = phoneSize;
  tester.view.devicePixelRatio = phoneDpr;
  tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
  WidgetsApp.debugAllowBannerOverride = false;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearPlatformBrightnessTestValue();
    WidgetsApp.debugAllowBannerOverride = true;
  });

  final shell = V6MainScreen(ctrl: Core.get<TopBarController>(), nav: NavigationPopObserver());
  await tester.pumpWidget(BlokadaApp(content: shell, isFamily: false));
  await tester.pump();
  if (path != null) {
    Navigation.open(path);
    await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 5)).catchError((_) => 0); // repeating animations never settle
  }
  // Images (Image.asset, the power button's icons) decode on real async I/O, which
  // the fake test clock does not advance; alternate real waits with fake-time pumps
  // so decoding finishes and the entry animations reach their end state.
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(seconds: 2));
  }
  debugDefaultTargetPlatformOverride = null;

  await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));

  // Unmount and let pending timers (debounces, short sleeps) fire before the test ends.
  // StandardRoute adds a listener to secondaryAnimation on every build but removes it
  // from `animation`, so after the shell (and its TopBarController) is gone the route
  // animation still notifies it. The app never unmounts the shell; tolerate only that.
  final onError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('TopBarController was used after being disposed')) return;
    onError?.call(details);
  };
  try {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 10));
  } finally {
    FlutterError.onError = onError;
  }
}
