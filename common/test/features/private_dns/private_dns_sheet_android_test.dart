import 'package:common/src/app_variants/family/module/perm/perm.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/features/modal/domain/modal.dart';
import 'package:common/src/features/private_dns/domain/private_dns_setup.dart';
import 'package:common/src/features/private_dns/ui/private_dns_sheet_android.dart';
import 'package:common/src/platform/perm/channel.pg.dart';
import 'package:common/src/platform/perm/perm.dart';
import 'package:common/src/shared/automation/ids.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tools.dart';
import 'private_dns_setup_test.dart';

const _tag = "abc123";
const _hostname = "pixel-abc123.cloud.blokada.org";

class _FakeProvider extends PrivateDnsStringProvider {
  @override
  String getAndroidDnsString() => _hostname;

  @override
  String getDeviceTag() => _tag;
}

const _theme = BlokadaTheme(
  bgColor: Color(0xFFF2F1F6),
  bgColorHome1: Colors.white,
  bgColorHome2: Colors.white,
  bgColorHome3: Colors.white,
  bgColorCard: Colors.white,
  panelBackground: Colors.white,
  cloud: Color(0xFF007AFF),
  accent: Color(0xffe450ba),
  freemium: Color(0xFF48A9A6),
  shadow: Color(0xffe8e8e8),
  bgMiniCard: Colors.white,
  textPrimary: Colors.black,
  textSecondary: Colors.black54,
  divider: Colors.black26,
);

class _Setup {
  final FakeDnsChannel channel;
  final CurrentModalValue modal;
  final List<String?> clipboard;

  _Setup(this.channel, this.modal, this.clipboard);
}

Future<_Setup> _pump(
  WidgetTester tester,
  Marker m, {
  required String manufacturer,
  PrivateDnsState? state,
  bool failClipboard = false,
  Size? size,
}) async {
  Core.act = ActScreenplay(ActScenario.test, Flavor.v6, PlatformType.android);
  final channel = FakeDnsChannel(state ?? dnsState(null));
  Core.register<PermChannel>(channel);
  Core.register<PrivateDnsStringProvider>(_FakeProvider());
  final modal = CurrentModalValue();
  Core.register(modal);
  await modal.change(m, Modal.onboardPrivateDns);

  final clipboard = <String?>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (
    call,
  ) async {
    if (call.method == "Clipboard.setData") {
      if (failClipboard) throw PlatformException(code: "clipboard");
      clipboard.add((call.arguments as Map)["text"] as String?);
    }
    return null;
  });

  if (size != null) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: const [_theme]),
      home: PrivateDnsSheetAndroid(
        manufacturer: manufacturer,
        successDelay: Duration.zero,
        copiedBeforeSettingsDelay: Duration.zero,
        verifier: PrivateDnsSetupVerifier(channel: channel),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _Setup(channel, modal, clipboard);
}

Finder _byId(String id) =>
    find.byWidgetPredicate((w) => w is Semantics && w.properties.identifier == id);

void main() {
  testWidgets("icon-only copy button copies the real hostname", (tester) async {
    await withTrace((m) async {
      final handle = tester.ensureSemantics();
      final s = await _pump(tester, m, manufacturer: "Google");

      expect(find.text(privateDnsDisplayHostname(_hostname)), findsOneWidget);
      expect(_byId(AutomationIds.dnsCopyHostname), findsOneWidget);
      expect(find.text("universal action copy".i18n), findsNothing);
      // Merged, as a screen reader and Appium see it.
      final copy = tester.getSemantics(_byId(AutomationIds.dnsCopyHostname)).getSemanticsData();
      expect(copy.identifier, AutomationIds.dnsCopyHostname);
      expect(copy.label, "universal action copy".i18n);
      expect(copy.hasFlag(SemanticsFlag.isButton), isTrue);

      await tester.tap(find.byIcon(Icons.copy));
      await tester.pumpAndSettle();
      expect(s.clipboard, [_hostname]);
      expect(find.byIcon(Icons.check), findsOneWidget);
      handle.dispose();
    });
  });

  test("displayed hostname breaks only after dots", () {
    const host = "samsung--SMG950F-a1b2c3d4e5.cloud.blokada.org";
    final shown = privateDnsDisplayHostname(host);
    // Real hyphens stay (U+2011 draws like a dot in monospace), and a
    // zero-width space follows each dot.
    expect(shown.contains("\u2011"), isFalse);
    expect(shown.contains(" "), isFalse);
    for (var i = 0; i < shown.length; i++) {
      if (shown[i] == "\u200B") expect(shown[i - 1], ".");
      if (shown[i] == ".") expect(shown[i + 1], "\u200B");
    }
    expect(shown.replaceAll("\u200B", ""), host);
  });

  testWidgets("narrow screen wraps the hostname only after a dot", (tester) async {
    await withTrace((m) async {
      await _pump(tester, m, manufacturer: "Google", size: const Size(300, 800));
      final shown = privateDnsDisplayHostname(_hostname);
      final paragraph = tester.renderObject<RenderParagraph>(find.text(shown));
      // Lay the same text out again to read where its lines end.
      final painter = TextPainter(
        text: paragraph.text,
        textDirection: TextDirection.ltr,
        textScaler: paragraph.textScaler,
      )..layout(maxWidth: paragraph.size.width);
      addTearDown(painter.dispose);
      final lines = painter.computeLineMetrics();
      expect(lines.length, greaterThan(1));
      // Every line but the last ends right after a dot's zero-width space.
      for (final line in lines.take(lines.length - 1)) {
        final pos = painter.getPositionForOffset(Offset(0, line.baseline));
        final end = painter.getLineBoundary(pos).end;
        expect(shown.substring(end - 2, end), ".\u200B");
      }
    });
  });

  testWidgets("a label too long for one line scales the hostname down", (tester) async {
    const host = "Google--sdkgphone64arm64-2138cb7c30e.cloud.blokada.org";
    await tester.pumpWidget(const MaterialApp(
      home: Center(child: SizedBox(width: 240, child: PrivateDnsHostnameText(host))),
    ));
    final shown = privateDnsDisplayHostname(host);
    final text = tester.widget<Text>(find.text(shown));
    expect(text.style!.fontSize, lessThan(14));

    final paragraph = tester.renderObject<RenderParagraph>(find.text(shown));
    final painter = TextPainter(
      text: paragraph.text,
      textDirection: TextDirection.ltr,
      textScaler: paragraph.textScaler,
    )..layout(maxWidth: paragraph.size.width);
    addTearDown(painter.dispose);
    // No label is split: every line but the last ends right after a dot.
    final lines = painter.computeLineMetrics();
    for (final line in lines.take(lines.length - 1)) {
      final pos = painter.getPositionForOffset(Offset(0, line.baseline));
      final end = painter.getLineBoundary(pos).end;
      expect(shown.substring(end - 2, end), ".\u200B");
    }
  });

  testWidgets("a short window with large text scrolls to Open Settings", (tester) async {
    await withTrace((m) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final s = await _pump(tester, m, manufacturer: "Google", size: const Size(360, 420));
      expect(tester.takeException(), isNull);

      final open = find.text("dnsprofile action open settings".i18n);
      await tester.scrollUntilVisible(open, 100, scrollable: find.byType(Scrollable).first);
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(s.channel.openSettingsCalls, 1);
    });
  });

  testWidgets("header stays on one line at a narrow width", (tester) async {
    await withTrace((m) async {
      await _pump(tester, m, manufacturer: "Google", size: const Size(300, 800));
      final header = find.text("private dns android header".i18n);
      final fitted = find.ancestor(of: header, matching: find.byType(FittedBox));
      expect(fitted, findsOneWidget);
      expect(tester.widget<FittedBox>(fitted).fit, BoxFit.scaleDown);
      expect(tester.widget<Text>(header).maxLines, 1);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets("Open Settings without Copy copies visibly, then opens Settings", (tester) async {
    await withTrace((m) async {
      final s = await _pump(tester, m, manufacturer: "Google");
      expect(find.byIcon(Icons.check), findsNothing);

      await tester.tap(find.text("dnsprofile action open settings".i18n));
      await tester.pumpAndSettle();

      expect(s.clipboard, [_hostname]);
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.text("private dns android copied hint".i18n), findsOneWidget);
      expect(s.channel.openSettingsCalls, 1);
      // The sheet stays, so it can check the result on return.
      expect(find.byType(PrivateDnsSheetAndroid), findsOneWidget);
    });
  });

  testWidgets("a failed copy still opens Settings, without claiming a copy", (tester) async {
    await withTrace((m) async {
      final s = await _pump(tester, m, manufacturer: "Google", failClipboard: true);

      await tester.tap(find.text("dnsprofile action open settings".i18n));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.check), findsNothing);
      expect(find.text("private dns android copied hint".i18n), findsNothing);
      expect(s.channel.openSettingsCalls, 1);
    });
  });

  testWidgets("Settings failing to open keeps the setup step", (tester) async {
    await withTrace((m) async {
      final s = await _pump(tester, m, manufacturer: "Google");
      s.channel.failOpenSettings = true;

      await tester.tap(find.text("dnsprofile action open settings".i18n));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      s.channel.state = dnsState("other.example.com");
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text(privateDnsDisplayHostname(_hostname)), findsOneWidget);
    });
  });

  testWidgets("Open Settings after Copy does not copy again", (tester) async {
    await withTrace((m) async {
      final s = await _pump(tester, m, manufacturer: "Google");

      await tester.tap(find.byIcon(Icons.copy));
      await tester.pumpAndSettle();
      await tester.tap(find.text("dnsprofile action open settings".i18n));
      await tester.pumpAndSettle();

      expect(s.clipboard, [_hostname]);
      expect(find.text("private dns android copied hint".i18n), findsNothing);
      expect(s.channel.openSettingsCalls, 1);
    });
  });

  final oemSteps = {
    "samsung": "private dns android step samsung more",
    "Google": "private dns android step pixel network",
    "Xiaomi": "private dns android step connection sharing",
    "OnePlus": "private dns android step choose designated",
    "motorola": "private dns android step search",
  };
  for (final entry in oemSteps.entries) {
    testWidgets("shows the steps for ${entry.key}", (tester) async {
      await withTrace((m) async {
        await _pump(tester, m, manufacturer: entry.key);
        expect(find.text(entry.value.i18n), findsOneWidget);
        for (final other in oemSteps.values.where((v) => v != entry.value)) {
          // Xiaomi and OnePlus share their first step.
          if (entry.key == "OnePlus" && other == "private dns android step connection sharing") {
            continue;
          }
          expect(find.text(other.i18n), findsNothing);
        }
      });
    });
  }

  testWidgets("matching hostname shows success and closes the sheet", (tester) async {
    await withTrace((m) async {
      final s = await _pump(tester, m, manufacturer: "Google", state: dnsState(_hostname));
      expect(s.modal.present, null);
    });
  });

  testWidgets("another device's Blokada hostname shows the setup step", (tester) async {
    await withTrace((m) async {
      final s = await _pump(
        tester,
        m,
        manufacturer: "samsung",
        state: dnsState("samsung-zzz999.cloud.blokada.org"),
      );
      expect(find.text("private dns android header".i18n), findsOneWidget);
      expect(_byId(AutomationIds.dnsOpenSettings), findsOneWidget);
      expect(_byId(AutomationIds.dnsSetupSuccess), findsNothing);
      expect(s.modal.present, Modal.onboardPrivateDns);
    });
  });

  testWidgets("returning with this device's hostname closes the sheet", (tester) async {
    await withTrace((m) async {
      final s = await _pump(tester, m, manufacturer: "Google");
      await tester.tap(find.text("dnsprofile action open settings".i18n));
      await tester.pumpAndSettle();
      expect(s.modal.present, Modal.onboardPrivateDns);

      s.channel.state = dnsState(_hostname);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(s.modal.present, null);
    });
  });
}
