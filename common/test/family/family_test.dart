import 'package:common/core/core.dart';
import 'package:common/dragon/family/family.dart';
import 'package:common/lock/lock.dart';
import 'package:common/lock/value.dart';
import 'package:common/platform/account/account.dart';
import 'package:common/platform/app/app.dart';
import 'package:common/platform/device/device.dart';
import 'package:common/platform/journal/journal.dart';
import 'package:common/platform/perm/perm.dart';
import 'package:common/platform/stage/stage.dart';
import 'package:common/platform/stats/stats.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';

import '../tools.dart';
@GenerateNiceMocks([
  MockSpec<FamilyStore>(),
  MockSpec<DeviceStore>(),
  MockSpec<AccountStore>(),
  MockSpec<IsLocked>(),
  MockSpec<AppStore>(),
  MockSpec<StageStore>(),
  MockSpec<JournalStore>(),
  MockSpec<StatsStore>(),
  MockSpec<PermStore>(),
])
import 'family_test.mocks.dart';

void main() {
  group("store", () {
    test("linkDeviceBasicTest", () async {
      await withTrace((m) async {
        DI.register<AccountStore>(MockAccountStore());
        DI.register<IsLocked>(MockIsLocked());
        DI.register<AppStore>(MockAppStore());
        DI.register<StageStore>(MockStageStore());
        DI.register<JournalStore>(MockJournalStore());
        DI.register<StatsStore>(MockStatsStore());
        DI.register<PermStore>(MockPermStore());

        final device = MockDeviceStore();
        DI.register<DeviceStore>(device);

        final subject = FamilyStore();
        mockAct(subject, flavor: Flavor.family);
        // await subject.link("abcdef", "Test%20Device");
        //
        // verify(device.setDeviceAlias(any, "Test Device"));
        // verify(device.setLinkedTag(any, "abcdef"));
      });
    });
  });
}
