import 'package:common/core/core.dart';
import 'package:common/platform/app/app.dart';
import 'package:common/platform/device/device.dart';
import 'package:common/platform/perm/channel.pg.dart';
import 'package:common/platform/perm/perm.dart';
import 'package:common/platform/stage/stage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';

import '../../tools.dart';
@GenerateNiceMocks([
  MockSpec<DeviceStore>(),
  MockSpec<PermOps>(),
  MockSpec<AppStore>(),
  MockSpec<StageStore>(),
])
import 'actor_test.mocks.dart';

void main() {
  group("store", () {
    test("permsEnabled", () async {
      await withTrace((m) async {
        Core.register<StageStore>(MockStageStore());

        final app = MockAppStore();
        Core.register<AppStore>(app);

        final device = MockDeviceStore();
        Core.register<DeviceStore>(device);

        final ops = MockPermOps();
        Core.register<PermOps>(ops);

        final dnsEnabledFor = PrivateDnsEnabledFor();
        Core.register(dnsEnabledFor);

        final subject = PlatformPermActor();
        expect(dnsEnabledFor.present, null);

        await subject.setPrivateDnsEnabled("tag", m);
        expect(dnsEnabledFor.present, "tag");

        await subject.setPrivateDnsDisabled(m);
        expect(dnsEnabledFor.present, null);
      });
    });
  });
}
