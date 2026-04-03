import 'dart:collection';
import 'dart:convert';

import 'package:common/src/app_variants/family/module/perm/perm.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/features/plus/domain/plus.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/platform/account/api.dart';
import 'package:common/src/platform/app/app.dart';
import 'package:common/src/platform/app/channel.act.dart';
import 'package:common/src/platform/app/channel.pg.dart';
import 'package:common/src/platform/device/device.dart';
import 'package:common/src/platform/perm/channel.pg.dart';
import 'package:common/src/platform/perm/dnscheck.dart';
import 'package:common/src/platform/perm/perm.dart';
import 'package:common/src/platform/stage/stage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../tools.dart';
import '../account/fixtures.dart';

@GenerateNiceMocks([
  MockSpec<AccountStore>(),
  MockSpec<AppStore>(),
  MockSpec<DeviceStore>(),
  MockSpec<PlusActor>(),
  MockSpec<StageStore>(),
])
import 'actor_test.mocks.dart';

class _FakePermChannel with PermChannel {
  _FakePermChannel({required List<PrivateDnsState> privateDnsStates})
      : _privateDnsStates = Queue.of(privateDnsStates);

  final Queue<PrivateDnsState> _privateDnsStates;

  var getPrivateDnsStateCalls = 0;
  var doVpnEnabledCalls = 0;

  @override
  Future<bool> doAuthenticate() async => true;

  @override
  Future<void> doAskNotificationPerms() async {}

  @override
  Future<void> doAskVpnPerms() async {}

  @override
  Future<bool> doNotificationEnabled() async => false;

  @override
  Future<void> doOpenPermSettings() async {}

  @override
  Future<void> doSetDns(String tag) async {}

  @override
  Future<void> doSetPrivateDnsEnabled(String tag, String alias) async {}

  @override
  Future<bool> doVpnEnabled() async {
    doVpnEnabledCalls += 1;
    return false;
  }

  @override
  Future<PrivateDnsState> getPrivateDnsState() async {
    getPrivateDnsStateCalls += 1;
    if (_privateDnsStates.isEmpty) {
      return unavailableDnsState();
    }
    if (_privateDnsStates.length == 1) {
      return _privateDnsStates.first;
    }
    return _privateDnsStates.removeFirst();
  }

  @override
  Future<bool> isRunningOnMac() async => false;
}

class _FakeSchedulerTimer extends SchedulerTimer {
  Duration? nextDelay;
  DateTime _now = DateTime.utc(2026, 3, 25, 12);

  @override
  setTimer(Duration? inWhen) {
    nextDelay = inWhen;
  }

  @override
  DateTime now() => _now;

  void advance(Duration duration) {
    _now = _now.add(duration);
  }
}

class _Harness {
  _Harness({
    required this.app,
    required this.channel,
    required this.dnsEnabledFor,
    required this.subject,
    required this.timer,
  });

  final AppStore app;
  final _FakePermChannel channel;
  final PrivateDnsEnabledForValue dnsEnabledFor;
  final PlatformPermActor subject;
  final _FakeSchedulerTimer timer;
}

Future<_Harness> createHarness(
  Marker m, {
  StageRouteState? route,
  List<PrivateDnsState> privateDnsStates = const [],
  String? deviceTag = "225024",
  String deviceAlias = "iPhone",
  bool cloudEnabled = true,
}) async {
  final stage = MockStageStore();
  when(stage.route).thenReturn(route ?? StageRouteState.init().newFg());
  Core.register<StageStore>(stage);

  final timer = _FakeSchedulerTimer();
  final scheduler = Scheduler(timer: timer);
  Core.register<Scheduler>(scheduler);
  await scheduler.eventTriggered(m, Event.appForeground, value: "1");

  final account = MockAccountStore();
  when(account.account).thenReturn(AccountState(
    "mockedmocked",
    JsonAccount.fromJson(jsonDecode(fixtureJsonAccount)),
  ));
  when(account.isFreemium).thenReturn(false);
  when(account.type).thenReturn(AccountType.cloud);
  Core.register<AccountStore>(account);

  final device = MockDeviceStore();
  when(device.cloudEnabled).thenReturn(cloudEnabled);
  when(device.deviceTag).thenReturn(deviceTag);
  when(device.deviceAlias).thenReturn(deviceAlias);
  when(device.pausedForSeconds).thenReturn(0);
  Core.register<DeviceStore>(device);

  Core.register<AppOps>(getOps());
  final app = AppStore();
  Core.register<AppStore>(app);
  await app.initStarted(m);
  await app.initCompleted(m);
  await app.onAccountChanged(m);
  await app.onDeviceChanged(m);

  Core.register<PlusActor>(MockPlusActor());
  Core.register<PermChannel>(_FakePermChannel(
    privateDnsStates: privateDnsStates.isEmpty
        ? [unavailableDnsState()]
        : privateDnsStates,
  ));
  Core.register(PrivateDnsEnabledForValue());
  Core.register(NotificationEnabledValue());
  Core.register(VpnEnabledValue());
  Core.register(PrivateDnsCheck());

  final channel = Core.get<PermChannel>() as _FakePermChannel;
  final dnsEnabledFor = Core.get<PrivateDnsEnabledForValue>();
  final subject = PlatformPermActor();

  return _Harness(
    app: app,
    channel: channel,
    dnsEnabledFor: dnsEnabledFor,
    subject: subject,
    timer: timer,
  );
}

void main() {
  group("store", () {
    test("permsEnabled", () async {
      await withTrace((m) async {
        Core.register<StageStore>(MockStageStore());
        Core.register<AppStore>(MockAppStore());
        Core.register<DeviceStore>(MockDeviceStore());
        Core.register<PlusActor>(MockPlusActor());
        Core.register<PermChannel>(_FakePermChannel(
          privateDnsStates: [unavailableDnsState()],
        ));
        Core.register(PrivateDnsEnabledForValue());
        Core.register(NotificationEnabledValue());
        Core.register(VpnEnabledValue());
        Core.register(PrivateDnsCheck());
        Core.register<Scheduler>(Scheduler(timer: _FakeSchedulerTimer()));

        final subject = PlatformPermActor();
        final dnsEnabledFor = Core.get<PrivateDnsEnabledForValue>();
        expect(dnsEnabledFor.present, null);

        await subject.setPrivateDnsEnabled("tag", m);
        expect(dnsEnabledFor.present, "tag");

        await subject.setPrivateDnsDisabled(m);
        expect(dnsEnabledFor.present, null);
      });
    });

    test("foreground unavailable iOS read enters checking", () async {
      await withTrace((m) async {
        final harness = await createHarness(
          m,
          route: StageRouteState.init().newFg(),
          privateDnsStates: [unavailableDnsState()],
          deviceTag: "225024",
          deviceAlias: "iPhone",
        );
        await harness.dnsEnabledFor.change(m, "225024");

        await harness.subject.syncPerms(m);

        expect(harness.channel.getPrivateDnsStateCalls, 1);
        expect(harness.channel.doVpnEnabledCalls, 1);
        expect(harness.dnsEnabledFor.present, "225024");
        expect(harness.timer.nextDelay, const Duration(milliseconds: 500));
        expect(harness.app.conditions.cloudPermCheckSettled, isFalse);
        expect(harness.app.status, AppStatus.initializing);
      });
    });

    test("repeated unavailable iOS reads retry for 1.5 seconds then mismatched", () async {
      await withTrace((m) async {
        final harness = await createHarness(
          m,
          route: StageRouteState.init().newFg(),
          privateDnsStates: [
            unavailableDnsState(),
            unavailableDnsState(),
            unavailableDnsState(),
            unavailableDnsState(),
          ],
          deviceTag: "225024",
          deviceAlias: "iPhone",
        );
        await harness.dnsEnabledFor.change(m, "225024");

        await harness.subject.syncPerms(m);
        expect(harness.app.conditions.cloudPermCheckSettled, isFalse);

        for (var i = 0; i < 3; i++) {
          expect(harness.timer.nextDelay, const Duration(milliseconds: 500));
          harness.timer.advance(harness.timer.nextDelay!);
          await harness.timer.callback();
        }

        expect(harness.channel.getPrivateDnsStateCalls, 4);
        expect(harness.dnsEnabledFor.present, null);
        expect(harness.app.conditions.cloudPermCheckSettled, isTrue);
        expect(harness.app.status, AppStatus.deactivated);
      });
    });

    test("enabled correct read resolves matched", () async {
      await withTrace((m) async {
        final harness = await createHarness(
          m,
          route: StageRouteState.init().newFg(),
          privateDnsStates: [
            enabledDnsState("https://cloud.blokada.org/225024/iPhone"),
          ],
          deviceTag: "225024",
          deviceAlias: "iPhone",
        );

        await harness.subject.syncPerms(m);

        expect(harness.dnsEnabledFor.present, "225024");
        expect(harness.app.conditions.cloudPermEnabled, isTrue);
        expect(harness.app.conditions.cloudPermCheckSettled, isTrue);
        expect(harness.app.status, AppStatus.activatedCloud);
      });
    });

    test("enabled incorrect read resolves mismatched", () async {
      await withTrace((m) async {
        final harness = await createHarness(
          m,
          route: StageRouteState.init().newFg(),
          privateDnsStates: [
            enabledDnsState("https://cloud.blokada.org/other/iPhone"),
          ],
          deviceTag: "225024",
          deviceAlias: "iPhone",
        );
        await harness.dnsEnabledFor.change(m, "225024");

        await harness.subject.syncPerms(m);

        expect(harness.dnsEnabledFor.present, null);
        expect(harness.app.conditions.cloudPermCheckSettled, isTrue);
        expect(harness.app.status, AppStatus.deactivated);
      });
    });

    test("disabled read resolves mismatched immediately without retry", () async {
      await withTrace((m) async {
        final harness = await createHarness(
          m,
          route: StageRouteState.init().newFg(),
          privateDnsStates: [
            disabledDnsState("https://cloud.blokada.org/225024/iPhone"),
          ],
          deviceTag: "225024",
          deviceAlias: "iPhone",
        );
        await harness.dnsEnabledFor.change(m, "225024");

        await harness.subject.syncPerms(m);

        expect(harness.channel.getPrivateDnsStateCalls, 1);
        expect(harness.timer.nextDelay, isNull);
        expect(harness.dnsEnabledFor.present, null);
        expect(harness.app.conditions.cloudPermCheckSettled, isTrue);
        expect(harness.app.status, AppStatus.deactivated);
      });
    });

    test("enabled missing url retries before mismatching", () async {
      await withTrace((m) async {
        final harness = await createHarness(
          m,
          route: StageRouteState.init().newFg(),
          privateDnsStates: [
            enabledDnsState(null),
            enabledDnsState(null),
            enabledDnsState(null),
            enabledDnsState(null),
          ],
          deviceTag: "225024",
          deviceAlias: "iPhone",
        );
        await harness.dnsEnabledFor.change(m, "225024");

        await harness.subject.syncPerms(m);
        expect(harness.app.conditions.cloudPermCheckSettled, isFalse);

        for (var i = 0; i < 3; i++) {
          expect(harness.timer.nextDelay, const Duration(milliseconds: 500));
          harness.timer.advance(harness.timer.nextDelay!);
          await harness.timer.callback();
        }

        expect(harness.channel.getPrivateDnsStateCalls, 4);
        expect(harness.dnsEnabledFor.present, null);
        expect(harness.app.conditions.cloudPermCheckSettled, isTrue);
        expect(harness.app.status, AppStatus.deactivated);
      });
    });

    test("background does not drive the foreground-only retry loop", () async {
      await withTrace((m) async {
        final harness = await createHarness(
          m,
          route: StageRouteState.init().newFg(),
          privateDnsStates: [
            unavailableDnsState(),
            enabledDnsState("https://cloud.blokada.org/225024/iPhone"),
          ],
          deviceTag: "225024",
          deviceAlias: "iPhone",
        );

        await harness.subject.syncPerms(m);
        expect(harness.app.conditions.cloudPermCheckSettled, isFalse);

        await harness.subject.onRouteChanged(StageRouteState.init(), m);
        expect(harness.timer.nextDelay, null);
        expect(harness.app.conditions.cloudPermCheckSettled, isTrue);

        await harness.timer.callback();
        expect(harness.channel.getPrivateDnsStateCalls, 1);
      });
    });
  });

  group("android", () {
    test("disabled DNS settles immediately without deferral", () async {
      await withTrace((m) async {
        Core.act = ActScreenplay(ActScenario.test, Flavor.v6, PlatformType.android);
        final harness = await createHarness(
          m,
          route: StageRouteState.init().newFg(),
          privateDnsStates: [disabledDnsState(null)],
          deviceTag: "225024",
          deviceAlias: "Pixel",
        );
        await harness.dnsEnabledFor.change(m, "225024");

        await harness.subject.syncPerms(m);

        expect(harness.channel.getPrivateDnsStateCalls, 1);
        expect(harness.timer.nextDelay, isNull);
        expect(harness.dnsEnabledFor.present, null);
        expect(harness.app.conditions.cloudPermCheckSettled, isTrue);
        expect(harness.app.status, AppStatus.deactivated);
      });
    });

    test("enabled correct DNS settles immediately", () async {
      await withTrace((m) async {
        Core.act = ActScreenplay(ActScenario.test, Flavor.v6, PlatformType.android);
        final harness = await createHarness(
          m,
          route: StageRouteState.init().newFg(),
          privateDnsStates: [
            enabledDnsState("Pixel-225024.cloud.blokada.org"),
          ],
          deviceTag: "225024",
          deviceAlias: "Pixel",
        );

        await harness.subject.syncPerms(m);

        expect(harness.channel.getPrivateDnsStateCalls, 1);
        expect(harness.dnsEnabledFor.present, "225024");
        expect(harness.app.conditions.cloudPermEnabled, isTrue);
        expect(harness.app.conditions.cloudPermCheckSettled, isTrue);
        expect(harness.app.status, AppStatus.activatedCloud);
      });
    });

    test("unavailable DNS settles immediately without retry on Android", () async {
      await withTrace((m) async {
        Core.act = ActScreenplay(ActScenario.test, Flavor.v6, PlatformType.android);
        final harness = await createHarness(
          m,
          route: StageRouteState.init().newFg(),
          privateDnsStates: [unavailableDnsState()],
          deviceTag: "225024",
          deviceAlias: "Pixel",
        );
        await harness.dnsEnabledFor.change(m, "225024");

        await harness.subject.syncPerms(m);

        // Android should NOT defer — settles immediately even for unavailable
        expect(harness.channel.getPrivateDnsStateCalls, 1);
        expect(harness.timer.nextDelay, isNull);
        expect(harness.app.conditions.cloudPermCheckSettled, isTrue);
        expect(harness.app.status, AppStatus.deactivated);
      });
    });
  });
}

PrivateDnsState enabledDnsState(String? serverUrl) {
  return PrivateDnsState(
    kind: PrivateDnsStateKind.enabled,
    serverUrl: serverUrl,
  );
}

PrivateDnsState disabledDnsState(String? serverUrl) {
  return PrivateDnsState(
    kind: PrivateDnsStateKind.disabled,
    serverUrl: serverUrl,
  );
}

PrivateDnsState unavailableDnsState() {
  return PrivateDnsState(
    kind: PrivateDnsStateKind.unavailable,
    serverUrl: null,
  );
}
