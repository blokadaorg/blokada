import 'dart:convert';
import 'dart:io';

import 'package:common/modules.dart';
import 'package:common/src/app_variants/v6/widget/main_screen.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/features/api/domain/api.dart';
import 'package:common/src/features/env/domain/env.dart';
import 'package:common/src/features/plus/domain/keypair/keypair.dart';
import 'package:common/src/platform/plus/plus.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:common/src/shared/ui/app.dart';
import 'package:common/src/shared/ui/top_bar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_http.dart';

/// Pixel size of the emulator the screenshots were taken on (MediumPhone, 420dpi).
const phoneSize = Size(1080, 2400);
const phoneDpr = 2.625;

/// Goldens are generated on Linux; macOS renders text and anti-aliasing
/// slightly differently, so comparisons there would always fail.
final goldenSkip = Platform.isLinux ? null : 'Goldens are generated and compared on Linux only';

bool _fontsLoaded = false;

Directory _flutterRoot() {
  final env = Platform.environment['FLUTTER_ROOT'];
  if (env != null && env.isNotEmpty) return Directory(env);
  // flutter_tester lives in <root>/bin/cache/artifacts/engine/<platform>/.
  var dir = File(Platform.resolvedExecutable).parent;
  while (dir.parent.path != dir.path) {
    if (Directory('${dir.path}/bin/cache/artifacts/material_fonts').existsSync()) return dir;
    dir = dir.parent;
  }
  throw StateError('Flutter SDK not found; set FLUTTER_ROOT');
}

/// The package root that pubspec.lock resolved, from .dart_tool/package_config.json.
Directory _packageRoot(String name) {
  final config = jsonDecode(File('.dart_tool/package_config.json').readAsStringSync());
  final pkg = (config['packages'] as List).firstWhere((p) => p['name'] == name,
      orElse: () => throw StateError('$name missing from package_config.json; run pub get'));
  return Directory.fromUri(Uri.parse(pkg['rootUri'] as String));
}

/// Tests render text with a placeholder font unless real fonts are registered.
/// Roboto (the Android system font) and the Material icons ship with the Flutter SDK;
/// Cupertino icons come from the cupertino_icons version pinned in pubspec.lock.
Future<void> loadFonts() async {
  if (_fontsLoaded) return;
  final fonts = '${_flutterRoot().path}/bin/cache/artifacts/material_fonts';

  Future<void> load(String family, Iterable<String> paths) async {
    final loader = FontLoader(family);
    for (final path in paths) {
      loader.addFont(Future.value(ByteData.sublistView(await File(path).readAsBytes())));
    }
    await loader.load();
  }

  final roboto = Directory(fonts)
      .listSync()
      .map((f) => f.path)
      .where((p) => p.contains('/Roboto-') && p.endsWith('.ttf'))
      .toList()
    ..sort();
  await load('Roboto', roboto);
  await load('MaterialIcons', ['$fonts/MaterialIcons-Regular.otf']);
  // Icon fonts from packages are registered under "packages/<name>/<family>".
  await load('packages/cupertino_icons/CupertinoIcons',
      ['${_packageRoot('cupertino_icons').path}/assets/CupertinoIcons.ttf']);
  _fontsLoaded = true;
}

/// Boots the app's real modules in test mode (no platform channels; HTTP served
/// by [FakeHttpChannel]) so screens can be rendered with stores seeded by the test.
Future<void> bootModules(WidgetTester tester, {PlatformType platform = PlatformType.android}) async {
  await tester.runAsync(() async {
    await loadFonts();
    await I18nService.loadTranslations();
    await Core.di.reset();

    // Reassignment is allowed only while modules register, for the two overrides below.
    Core.di.allowReassignment = true;
    try {
      // PlusModule's keypair actor starts loading before PlatformPlusModule registers
      // its channel; on a device real I/O hides that ordering, in tests it does not.
      Core.register<KeypairChannel>(NoOpPlusChannel());
      await Modules().create(ActScreenplay(ActScenario.test, Flavor.v6, platform));
      Core.register<HttpChannel>(FakeHttpChannel());
    } finally {
      Core.di.allowReassignment = false;
    }

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
    debugDefaultTargetPlatformOverride = null;
    tester.view.reset();
    tester.platformDispatcher.clearPlatformBrightnessTestValue();
    WidgetsApp.debugAllowBannerOverride = true;
  });

  final shell = V6MainScreen(ctrl: Core.get<TopBarController>(), nav: NavigationPopObserver());
  await tester.pumpWidget(BlokadaApp(content: shell, isFamily: false));
  await tester.pump();
  if (path != null) {
    Navigation.open(path);
    // Fixed pumps rather than pumpAndSettle: the active power button animates forever.
    await tester.pump(const Duration(milliseconds: 600));
  }

  // Images (Image.asset, the power button's icons) decode and fake HTTP responses
  // resolve on real async I/O, which the fake test clock does not advance;
  // alternate real waits with fake-time pumps until the screen reaches its end state.
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(seconds: 2));
  }

  // The platform override must be cleared before the golden comparison and the
  // binding's end-of-test invariant check; the teardown also covers early failures.
  debugDefaultTargetPlatformOverride = null;
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));

  // Unmount and let pending timers (debounces, short sleeps) fire before the test ends.
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(minutes: 10));
}
