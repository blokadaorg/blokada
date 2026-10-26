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
  List<Object?> probe = const ["cloud"],
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
      clipboard.add((call.arguments as Map)["text"] as String?);
    }
    return null;
  });

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: const [_theme]),
      home: PrivateDnsSheetAndroid(
        manufacturer: manufacturer,
        successDelay: Duration.zero,
        verifier: PrivateDnsSetupVerifier(
          channel: channel,
          check: FakeOwnerCheck(probe),
          probeDelay: Duration.zero,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _Setup(channel, modal, clipboard);
}

Finder _byId(String id) =>
    find.byWidgetPredicate((w) => w is Semantics && w.properties.identifier == id);

void main() {
  testWidgets("shows the hostname with a visible Copy button", (tester) async {
    await withTrace((m) async {
      final s = await _pump(tester, m, manufacturer: "Google");

      expect(find.text(_hostname), findsOneWidget);
      expect(_byId(AutomationIds.dnsCopyHostname), findsOneWidget);
      expect(find.text("universal action copy".i18n), findsOneWidget);

      await tester.tap(find.text("universal action copy".i18n));
      await tester.pumpAndSettle();
      expect(s.clipboard, [_hostname]);
    });
  });

  testWidgets("Open Settings opens Settings without touching the clipboard", (tester) async {
    await withTrace((m) async {
      final s = await _pump(tester, m, manufacturer: "Google");

      await tester.tap(find.text("dnsprofile action open settings".i18n));
      await tester.pumpAndSettle();

      expect(s.channel.openSettingsCalls, 1);
      expect(s.clipboard, isEmpty);
      // The sheet stays, so it can check the result on return.
      expect(find.byType(PrivateDnsSheetAndroid), findsOneWidget);
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

  testWidgets("verified DNS shows success and closes the sheet", (tester) async {
    await withTrace((m) async {
      final s = await _pump(
        tester,
        m,
        manufacturer: "Google",
        state: dnsState(_hostname),
        probe: ["cloud"],
      );
      expect(s.modal.present, null);
    });
  });

  testWidgets("returning with a matching but unrouted hostname shows help", (tester) async {
    await withTrace((m) async {
      final s = await _pump(tester, m, manufacturer: "samsung", probe: [null]);
      expect(_byId(AutomationIds.dnsSetupHelp), findsNothing);

      s.channel.state = dnsState(_hostname);
      await tester.tap(find.text("dnsprofile action open settings".i18n));
      await tester.pumpAndSettle();
      // FakeOwnerCheck answers null: DNS does not go through Blokada.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(_byId(AutomationIds.dnsSetupHelp), findsOneWidget);
      expect(find.text("private dns android help samsung".i18n), findsOneWidget);
      expect(find.text("support action chat".i18n), findsOneWidget);
      expect(s.modal.present, Modal.onboardPrivateDns);
    });
  });

  testWidgets("help leaves out the Samsung tip on other phones", (tester) async {
    await withTrace((m) async {
      await _pump(
        tester,
        m,
        manufacturer: "Google",
        state: dnsState(_hostname, broken: true),
        probe: [null],
      );
      expect(_byId(AutomationIds.dnsSetupHelp), findsOneWidget);
      expect(find.text("private dns android help samsung".i18n), findsNothing);
    });
  });
}
