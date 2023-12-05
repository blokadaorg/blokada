import 'package:common/account/account.dart';
import 'package:common/app/app.dart';
import 'package:common/device/device.dart';
import 'package:common/family/family.dart';
import 'package:common/journal/journal.dart';
import 'package:common/lock/lock.dart';
import 'package:common/perm/perm.dart';
import 'package:common/stage/stage.dart';
import 'package:common/stats/stats.dart';
import 'package:common/util/act.dart';
import 'package:common/util/di.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../tools.dart';
@GenerateNiceMocks([
  MockSpec<FamilyStore>(),
  MockSpec<DeviceStore>(),
  MockSpec<AccountStore>(),
  MockSpec<LockStore>(),
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
      await withTrace((trace) async {
        depend<AccountStore>(MockAccountStore());
        depend<LockStore>(MockLockStore());
        depend<AppStore>(MockAppStore());
        depend<StageStore>(MockStageStore());
        depend<JournalStore>(MockJournalStore());
        depend<StatsStore>(MockStatsStore());
        depend<PermStore>(MockPermStore());

        final device = MockDeviceStore();
        depend<DeviceStore>(device);

        final subject = FamilyStore();
        subject.attachAndSaveAct(
            ActScreenplay(ActScenario.platformIsMocked, "family"));
        await subject.link(trace, "abcdef", "Test%20Device");

        verify(device.setDeviceAlias(any, "Test Device"));
        verify(device.setLinkedTag(any, "abcdef"));
      });
    });
  });
}
