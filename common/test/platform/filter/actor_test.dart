import 'package:common/src/core/core.dart';
import 'package:common/src/features/account/domain/account.dart';
import 'package:common/src/features/filter/domain/filter.dart';
import 'package:common/src/platform/device/device.dart';
import 'package:common/src/platform/filter/filter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../tools.dart';
@GenerateNiceMocks([
  MockSpec<DeviceStore>(),
  MockSpec<AccountActor>(),
])
import 'actor_test.mocks.dart';

void main() {
  group("deviceSync", () {
    test("willReadSafeSearchFromDevice", () async {
      await awaitTrace((m) async {
        final device = MockDeviceStore();
        when(device.lists).thenReturn(["a", "b"]);
        when(device.safeSearch).thenReturn(true);
        Core.register<DeviceStore>(device);
        Core.register<AccountActor>(MockAccountActor());
        final config = CurrentConfig();
        Core.register<CurrentConfig>(config);

        await PlatformFilterActor().onDeviceChanged(m);

        expect(
          config.present,
          UserFilterConfig({"a", "b"}, {FilterConfigKey.safeSearch: true}),
        );
      });
    });

    test("willLeaveSafeSearchOutWhenOffOnDevice", () async {
      await awaitTrace((m) async {
        final device = MockDeviceStore();
        when(device.lists).thenReturn(["a"]);
        when(device.safeSearch).thenReturn(false);
        Core.register<DeviceStore>(device);
        Core.register<AccountActor>(MockAccountActor());
        final config = CurrentConfig();
        Core.register<CurrentConfig>(config);

        await PlatformFilterActor().onDeviceChanged(m);

        // Same shape FilterActor produces, so it does not see a change.
        expect(config.present, UserFilterConfig({"a"}, {}));
      });
    });

    test("willWriteSafeSearchWithLists", () async {
      await awaitTrace((m) async {
        final device = MockDeviceStore();
        when(device.lists).thenReturn(["a"]);
        when(device.safeSearch).thenReturn(false);
        Core.register<DeviceStore>(device);

        final subject = PlatformFilterActor();
        subject.onUserConfigChanged(
          UserFilterConfig({"a", "s"}, {FilterConfigKey.safeSearch: true}),
        );
        await Future.delayed(const Duration(milliseconds: 1100));

        verify(device.setLists(["a", "s"], any, safeSearch: true)).called(1);
      });
    });

    test("willTurnSafeSearchOffWithLists", () async {
      await awaitTrace((m) async {
        final device = MockDeviceStore();
        when(device.lists).thenReturn(["a", "s"]);
        when(device.safeSearch).thenReturn(true);
        Core.register<DeviceStore>(device);

        final subject = PlatformFilterActor();
        subject.onUserConfigChanged(UserFilterConfig({"a"}, {}));
        await Future.delayed(const Duration(milliseconds: 1100));

        verify(device.setLists(["a"], any, safeSearch: false)).called(1);
      });
    });

    test("willNotSendToggleUndoneBeforeDebounce", () async {
      await awaitTrace((m) async {
        final device = MockDeviceStore();
        when(device.lists).thenReturn(["a"]);
        when(device.safeSearch).thenReturn(false);
        Core.register<DeviceStore>(device);

        final subject = PlatformFilterActor();
        subject.onUserConfigChanged(
          UserFilterConfig({"a", "s"}, {FilterConfigKey.safeSearch: true}),
        );
        subject.onUserConfigChanged(UserFilterConfig({"a"}, {}));
        await Future.delayed(const Duration(milliseconds: 1100));

        verifyNever(
            device.setLists(any, any, safeSearch: anyNamed("safeSearch")));
      });
    });
  });
}
