import 'package:common/src/app_variants/family/module/device_v3/device.dart' show DeviceTag;
import 'package:common/src/app_variants/v6/widget/activity_screen.dart';
import 'package:common/src/app_variants/v6/widget/privacy_pulse_screen.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/features/api/domain/api.dart';
import 'package:common/src/features/journal/domain/journal.dart';
import 'package:common/src/features/settings/ui/retention_section.dart';
import 'package:common/src/features/stats/domain/controller.dart';
import 'package:common/src/features/stats/ui/activity_item.dart';
import 'package:common/src/platform/device/device.dart' hide DeviceTag;
import 'package:common/src/shared/automation/ids.dart';
import 'package:common/src/shared/ui/app.dart';
import 'package:common/src/shared/ui/blokada_switch.dart';
import 'package:common/src/shared/ui/top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mobx/mobx.dart' as mobx;

import '../../golden/fixtures.dart';
import '../../golden/golden_tools.dart';

/// Records the opt-in and turns logging on without a server, with empty
/// sections, as right after logging was turned on.
class _FakeStats extends StatsController {
  var enabled = 0;

  @override
  Future<void> openPulse(Marker m, {ToplistRange? initialRange}) async {
    stats.now = const StatsSection(StatsStatus.empty);
    counters.now = const StatsSection(StatsStatus.empty);
    toplists.now = const StatsSection(
      StatsStatus.empty,
      PulseToplists(entries: [], blockedDeltas: null, allowedDeltas: null),
    );
    recent.now = const StatsSection(StatsStatus.empty, RecentPreview(blocked: [], allowed: []));
  }

  @override
  void closePulse() {}

  @override
  Future<void> enableLogging(Marker m) async {
    enabled++;
    collecting.now = true;
    mobx.runInAction(() => Core.get<DeviceStore>().retention = "24h");
  }
}

/// A journal with nothing in it yet.
class _EmptyJournal extends JournalActor {
  @override
  fetch(Marker m, {DeviceTag? tag, bool append = false}) async {
    allEntries = [];
    filteredEntries.now = [];
  }
}

/// Saves the retention without a server.
class _LocalDevice extends DeviceStore {
  @override
  Future<void> setRetention(DeviceRetention retention, Marker m) async {
    mobx.runInAction(() => this.retention = retention);
  }
}

class _FailingDevice extends DeviceStore {
  @override
  Future<void> setRetention(DeviceRetention retention, Marker m) async {
    throw StateError("save failed");
  }
}

void _register<T extends Object>(T instance) {
  Core.di.allowReassignment = true;
  try {
    Core.register<T>(instance);
  } finally {
    Core.di.allowReassignment = false;
  }
}

Future<_FakeStats> _boot(WidgetTester tester) async {
  await bootModules(tester);
  await seedCloudAccount(tester);
  seedDevice();
  mobx.runInAction(() => Core.get<DeviceStore>().retention = "");
  final stats = _FakeStats();
  _register<StatsController>(stats);
  _register<JournalActor>(_EmptyJournal());
  return stats;
}

Future<void> _show(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => TopBarController(),
      child: BlokadaApp(isFamily: false, content: Scaffold(body: screen)),
    ),
  );
  await tester.pump();
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(minutes: 1));
}

Finder get _cta => find.text("activity logging action enable".i18n);
Finder get _offer => find.text("activity logging offer header".i18n);
Finder get _collecting => find.text("activity logging collecting".i18n);

void _expectOffer(WidgetTester tester) {
  expect(_offer, findsOneWidget);
  expect(find.text("activity logging offer brief".i18n), findsOneWidget);
  expect(find.text("activity logging sample".i18n.toUpperCase()), findsOneWidget);
  expect(find.byType(RetentionSection), findsNothing);
  // The whole label fits on the button.
  final label = tester.renderObject<RenderParagraph>(_cta);
  expect(label.didExceedMaxLines, isFalse);
  // Screen readers get the offer and the button, not the made-up data.
  expect(
    find.bySemanticsLabel(RegExp(RegExp.escape("activity logging offer header".i18n))),
    findsOneWidget,
  );
  expect(
    tester.getSemantics(_cta),
    containsSemantics(
      isButton: true,
      identifier: AutomationIds.loggingEnable,
      label: "activity logging action enable".i18n,
    ),
  );
}

void main() {
  group('Privacy Pulse with logging off', () {
    testWidgets('shows sample data behind the offer', (tester) async {
      final semantics = tester.ensureSemantics();
      await _boot(tester);
      await _show(tester, const PrivacyPulseScreen());

      _expectOffer(tester);
      final sampleCompany = FreemiumDataProvider.sampleBlockedCompanies.first;
      expect(find.text(sampleCompany), findsOneWidget);
      expect(find.bySemanticsLabel(sampleCompany), findsNothing);

      semantics.dispose();
      await _unmount(tester);
    });

    testWidgets('one tap turns logging on, then it says results are coming', (tester) async {
      final stats = await _boot(tester);
      await _show(tester, const PrivacyPulseScreen());

      await tester.tap(_cta);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(stats.enabled, 1);
      expect(_offer, findsNothing);
      // Top domains and recent activity, both still empty.
      expect(_collecting, findsNWidgets(2));
      expect(find.text("privacy pulse empty".i18n), findsNothing);

      stats.collecting.now = false;
      await tester.pump(const Duration(milliseconds: 600));
      expect(_collecting, findsNothing);
      expect(find.text("privacy pulse empty".i18n), findsNWidgets(2));

      await _unmount(tester);
    });
  });

  group('Activity with logging off', () {
    testWidgets('shows sample rows behind the offer', (tester) async {
      final semantics = tester.ensureSemantics();
      await _boot(tester);
      await _show(tester, const ActivityScreen());

      _expectOffer(tester);
      expect(find.byType(ActivityItem), findsWidgets);
      final sampleDomain = FreemiumDataProvider.sampleJournalDomains.first;
      expect(find.bySemanticsLabel(RegExp(RegExp.escape(sampleDomain))), findsNothing);

      semantics.dispose();
      await _unmount(tester);
    });

    testWidgets('one tap turns logging on, then it says results are coming', (tester) async {
      final stats = await _boot(tester);
      await _show(tester, const ActivityScreen());

      await tester.tap(_cta);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(stats.enabled, 1);
      expect(_offer, findsNothing);
      expect(_collecting, findsOneWidget);

      stats.collecting.now = false;
      await tester.pump();
      expect(_collecting, findsNothing);
      expect(find.text("universal status waiting for data".i18n), findsOneWidget);

      await _unmount(tester);
    });
  });

  group('StatsController.enableLogging', () {
    testWidgets('turns retention on and marks results as coming', (tester) async {
      await bootModules(tester);
      final device = _LocalDevice();
      _register<DeviceStore>(device);
      final controller = StatsController();

      await tester.runAsync(() => controller.enableLogging(Markers.testing));
      expect(device.retention, "24h");
      expect(controller.collecting.now, isTrue);
    });

    testWidgets('a failed save leaves nothing marked', (tester) async {
      await bootModules(tester);
      _register<DeviceStore>(_FailingDevice());
      final controller = StatsController();

      Object? error;
      await tester.runAsync(() async {
        try {
          await controller.enableLogging(Markers.testing);
        } catch (e) {
          error = e;
        }
      });
      expect(error, isA<StateError>());
      expect(controller.collecting.now, isFalse);
    });
  });

  testWidgets('the Settings switch still turns logging on', (tester) async {
    await bootModules(tester);
    final device = _LocalDevice();
    _register<DeviceStore>(device);
    mobx.runInAction(() => device.retention = "");
    await _show(tester, const RetentionSection());

    await tester.tap(find.byType(BlokadaSwitch));
    await tester.pump();
    expect(device.retention, "24h");

    await _unmount(tester);
  });
}
