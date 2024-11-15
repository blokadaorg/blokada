import 'package:common/core/core.dart';
import 'package:common/platform/app/app.dart';
import 'package:common/platform/device/device.dart';
import 'package:common/platform/perm/channel.pg.dart';
import 'package:common/platform/perm/perm.dart';
import 'package:common/platform/stage/stage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';

import '../tools.dart';
@GenerateNiceMocks([
  MockSpec<DeviceStore>(),
  MockSpec<PermStore>(),
  MockSpec<PermOps>(),
  MockSpec<AppStore>(),
  MockSpec<StageStore>(),
])
import 'perm_test.mocks.dart';

void main() {
  group("store", () {
    test("permsEnabled", () async {
      await withTrace((m) async {
        depend<StageStore>(MockStageStore());

        final app = MockAppStore();
        depend<AppStore>(app);

        final device = MockDeviceStore();
        depend<DeviceStore>(device);

        final ops = MockPermOps();
        depend<PermOps>(ops);

        final subject = PermStore();
        expect(subject.privateDnsEnabledFor, null);

        await subject.setPrivateDnsEnabled("tag", m);
        expect(subject.privateDnsEnabledFor, "tag");

        await subject.setPrivateDnsDisabled(m);
        expect(subject.privateDnsEnabledFor, null);
      });
    });

    test("incrementTagChangeCounter", () async {
      await withTrace((m) async {
        depend<StageStore>(MockStageStore());

        final app = MockAppStore();
        depend<AppStore>(app);

        final device = MockDeviceStore();
        depend<DeviceStore>(device);

        final ops = MockPermOps();
        depend<PermOps>(ops);

        final subject = PermStore();
        expect(subject.privateDnsTagChangeCounter, 0);

        await subject.incrementPrivateDnsTagChangeCounter(m);
        expect(subject.privateDnsTagChangeCounter, 1);

        await subject.incrementPrivateDnsTagChangeCounter(m);
        expect(subject.privateDnsTagChangeCounter, 2);
      });
    });
  });
}
