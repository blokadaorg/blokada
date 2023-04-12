import 'package:common/device/device.dart';
import 'package:common/device/json.dart';
import 'package:common/perm/channel.pg.dart';
import 'package:common/perm/perm.dart';
import 'package:common/stage/stage.dart';
import 'package:common/util/di.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../tools.dart';
@GenerateNiceMocks([
  MockSpec<StageStore>(),
  MockSpec<DeviceStore>(),
  MockSpec<DeviceJson>(),
  MockSpec<PermStore>(),
  MockSpec<PermOps>(),
])
import 'perm_test.mocks.dart';

final _fixtureDevice = JsonDevice(
    deviceTag: "some-tag", lists: ["a", "b"], retention: "24h", paused: true);

void main() {
  group("store", () {
    test("permsEnabled", () async {
      await withTrace((trace) async {
        final subject = PermStore();
        expect(subject.privateDnsEnabled, null);

        await subject.setPrivateDnsEnabled(trace, "tag");
        expect(subject.privateDnsEnabled, "tag");

        await subject.setPrivateDnsDisabled(trace);
        expect(subject.privateDnsEnabled, null);
      });
    });

    test("incrementTagChangeCounter", () async {
      await withTrace((trace) async {
        final subject = PermStore();
        expect(subject.privateDnsTagChangeCounter, 0);

        await subject.incrementPrivateDnsTagChangeCounter(trace);
        expect(subject.privateDnsTagChangeCounter, 1);

        await subject.incrementPrivateDnsTagChangeCounter(trace);
        expect(subject.privateDnsTagChangeCounter, 2);
      });
    });
  });

  group("binder", () {
    test("onTagChange", () async {
      await withTrace((trace) async {
        final json = MockDeviceJson();
        when(json.getDevice(any))
            .thenAnswer((_) => Future.value(_fixtureDevice));
        di.registerSingleton<DeviceJson>(json);

        final device = DeviceStore();
        di.registerSingleton<DeviceStore>(device);

        final store = MockPermStore();
        di.registerSingleton<PermStore>(store);

        final subject = PermBinder();
        verifyNever(store.incrementPrivateDnsTagChangeCounter(trace));

        await device.fetch(trace);
        verify(store.incrementPrivateDnsTagChangeCounter(any)).called(1);
      });
    });

    test("onForeground", () async {
      await withTrace((trace) async {
        final json = MockDeviceJson();
        when(json.getDevice(any))
            .thenAnswer((_) => Future.value(_fixtureDevice));
        di.registerSingleton<DeviceJson>(json);

        final device = DeviceStore();
        di.registerSingleton<DeviceStore>(device);

        final stage = StageStore();
        di.registerSingleton<StageStore>(stage);

        final store = MockPermStore();
        di.registerSingleton<PermStore>(store);

        final ops = MockPermOps();
        when(ops.doPrivateDnsEnabled(any))
            .thenAnswer((_) => Future.value(true));
        di.registerSingleton<PermOps>(ops);

        final subject = PermBinder();

        stage.setReady(trace, true);
        await device.fetch(trace);
        await stage.setForeground(trace, true);

        verify(store.setPrivateDnsEnabled(any, "some-tag")).called(1);
      });
    });

    test("onTagCounterChange", () async {
      await withTrace((trace) async {
        final json = MockDeviceJson();
        when(json.getDevice(any))
            .thenAnswer((_) => Future.value(_fixtureDevice));
        di.registerSingleton<DeviceJson>(json);

        final device = DeviceStore();
        di.registerSingleton<DeviceStore>(device);

        final store = PermStore();
        di.registerSingleton<PermStore>(store);

        final ops = MockPermOps();
        di.registerSingleton<PermOps>(ops);

        final subject = PermBinder();

        await device.fetch(trace);
        verify(ops.doSetSetPrivateDnsEnabled("some-tag")).called(1);

        await store.incrementPrivateDnsTagChangeCounter(trace);
        verify(ops.doSetSetPrivateDnsEnabled("some-tag")).called(1);
      });
    });
  });
}
