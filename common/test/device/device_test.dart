import 'package:common/core/core.dart';
import 'package:common/platform/account/account.dart';
import 'package:common/platform/device/channel.pg.dart';
import 'package:common/platform/device/device.dart';
import 'package:common/platform/device/json.dart';
import 'package:common/platform/stage/stage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../tools.dart';
@GenerateNiceMocks([
  MockSpec<DeviceJson>(),
  MockSpec<DeviceOps>(),
  MockSpec<StageStore>(),
  MockSpec<AccountStore>(),
])
import 'device_test.mocks.dart';

final _fixtureJsonDevice = JsonDevice(
  deviceTag: "some-tag",
  lists: ["a", "b"],
  retention: "24h",
  paused: true,
  safeSearch: false,
);

void main() {
  group("store", () {
    test("willUpdateObservablesOnFetch", () async {
      await withTrace((m) async {
        depend<StageStore>(MockStageStore());
        depend<AccountStore>(MockAccountStore());

        final api = MockDeviceJson();
        when(api.getDevice(any))
            .thenAnswer((_) => Future.value(_fixtureJsonDevice));
        depend<DeviceJson>(api);

        final ops = MockDeviceOps();
        depend<DeviceOps>(ops);

        final subject = DeviceStore();
        mockAct(subject);

        subject.deviceTag = "some-tag";
        await subject.fetch(m);

        expect(subject.lists, ["a", "b"]);
        expect(subject.retention, "24h");
        expect(subject.cloudEnabled, false);
      });
    });

    test("willFetchOnCallsToActions", () async {
      await withTrace((m) async {
        depend<StageStore>(MockStageStore());
        depend<AccountStore>(MockAccountStore());

        final api = MockDeviceJson();
        when(api.getDevice(any))
            .thenAnswer((_) => Future.value(_fixtureJsonDevice));
        depend<DeviceJson>(api);

        final ops = MockDeviceOps();
        depend<DeviceOps>(ops);

        final subject = DeviceStore();
        subject.deviceTag = "some-tag";
        mockAct(subject);

        await subject.setCloudEnabled(true, m);
        verify(api.putDevice(m, paused: false)).called(1);

        await subject.setRetention("1h", m);
        verify(api.putDevice(m, retention: "1h")).called(1);

        await subject.setLists(["c", "d"], m);
        verify(api.putDevice(m, lists: ["c", "d"])).called(1);
      });
    });
  });

  // TODO: verify bad json input from api

  group("storeErrors", () {
    test("willNotUpdateObservablesOnFetchError", () async {
      await withTrace((m) async {
        depend<StageStore>(MockStageStore());
        depend<AccountStore>(MockAccountStore());

        final api = MockDeviceJson();
        when(api.getDevice(any)).thenThrow(Exception("test"));
        depend<DeviceJson>(api);

        final ops = MockDeviceOps();
        depend<DeviceOps>(ops);

        final subject = DeviceStore();
        subject.act = mockedAct;

        await expectLater(subject.fetch(m), throwsException);

        expect(subject.deviceTag, null);
        expect(subject.lists, null);
        expect(subject.retention, null);
        expect(subject.cloudEnabled, null);
      });
    });

    test("willPropagateFetchErrorOnCallsToActions", () async {
      await withTrace((m) async {
        depend<StageStore>(MockStageStore());
        depend<AccountStore>(MockAccountStore());

        final api = MockDeviceJson();
        when(api.getDevice(any)).thenThrow(Exception("test"));
        depend<DeviceJson>(api);

        final ops = MockDeviceOps();
        depend<DeviceOps>(ops);

        final subject = DeviceStore();
        subject.act = mockedAct;

        await expectLater(subject.setCloudEnabled(true, m), throwsException);
        await expectLater(subject.setRetention("1h", m), throwsException);
        await expectLater(subject.setLists(["c", "d"], m), throwsException);
      });
    });
  });
}
