import 'package:common/account/account.dart';
import 'package:common/device/channel.pg.dart';
import 'package:common/device/device.dart';
import 'package:common/device/json.dart';
import 'package:common/stage/stage.dart';
import 'package:common/util/di.dart';
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
    deviceTag: "some-tag", lists: ["a", "b"], retention: "24h", paused: true);

void main() {
  group("store", () {
    test("willUpdateObservablesOnFetch", () async {
      await withTrace((trace) async {
        depend<StageStore>(MockStageStore());
        depend<AccountStore>(MockAccountStore());

        final api = MockDeviceJson();
        when(api.getDevice(any))
            .thenAnswer((_) => Future.value(_fixtureJsonDevice));
        depend<DeviceJson>(api);

        final ops = MockDeviceOps();
        depend<DeviceOps>(ops);

        final subject = DeviceStore();

        await subject.fetch(trace);

        expect(subject.deviceTag, "some-tag");
        expect(subject.lists, ["a", "b"]);
        expect(subject.retention, "24h");
        expect(subject.cloudEnabled, false);
      });
    });

    test("willFetchOnCallsToActions", () async {
      await withTrace((trace) async {
        depend<StageStore>(MockStageStore());
        depend<AccountStore>(MockAccountStore());

        final api = MockDeviceJson();
        when(api.getDevice(any))
            .thenAnswer((_) => Future.value(_fixtureJsonDevice));
        depend<DeviceJson>(api);

        final ops = MockDeviceOps();
        depend<DeviceOps>(ops);

        final subject = DeviceStore();

        await subject.setCloudEnabled(trace, true);
        verify(api.putDevice(any, paused: false)).called(1);

        await subject.setRetention(trace, "1h");
        verify(api.putDevice(any, retention: "1h")).called(1);

        await subject.setLists(trace, ["c", "d"]);
        verify(api.putDevice(any, lists: ["c", "d"])).called(1);
      });
    });
  });

  // TODO: verify bad json input from api

  group("storeErrors", () {
    test("willNotUpdateObservablesOnFetchError", () async {
      await withTrace((trace) async {
        depend<StageStore>(MockStageStore());
        depend<AccountStore>(MockAccountStore());

        final api = MockDeviceJson();
        when(api.getDevice(any)).thenThrow(Exception("test"));
        depend<DeviceJson>(api);

        final ops = MockDeviceOps();
        depend<DeviceOps>(ops);

        final subject = DeviceStore();

        await expectLater(subject.fetch(trace), throwsException);

        expect(subject.deviceTag, null);
        expect(subject.lists, null);
        expect(subject.retention, null);
        expect(subject.cloudEnabled, null);
      });
    });

    test("willPropagateFetchErrorOnCallsToActions", () async {
      await withTrace((trace) async {
        depend<StageStore>(MockStageStore());
        depend<AccountStore>(MockAccountStore());

        final api = MockDeviceJson();
        when(api.getDevice(any)).thenThrow(Exception("test"));
        depend<DeviceJson>(api);

        final ops = MockDeviceOps();
        depend<DeviceOps>(ops);

        final subject = DeviceStore();

        await expectLater(
            subject.setCloudEnabled(trace, true), throwsException);
        await expectLater(subject.setRetention(trace, "1h"), throwsException);
        await expectLater(subject.setLists(trace, ["c", "d"]), throwsException);
      });
    });
  });
}
