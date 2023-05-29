import 'package:common/app/app.dart';
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
  MockSpec<DeviceStore>(),
  MockSpec<PermStore>(),
  MockSpec<PermOps>(),
  MockSpec<AppStore>(),
])
import 'perm_test.mocks.dart';

void main() {
  group("store", () {
    test("permsEnabled", () async {
      await withTrace((trace) async {
        final app = MockAppStore();
        depend<AppStore>(app);

        final device = MockDeviceStore();
        depend<DeviceStore>(device);

        final ops = MockPermOps();
        depend<PermOps>(ops);

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
        final app = MockAppStore();
        depend<AppStore>(app);

        final device = MockDeviceStore();
        depend<DeviceStore>(device);

        final ops = MockPermOps();
        depend<PermOps>(ops);

        final subject = PermStore();
        expect(subject.privateDnsTagChangeCounter, 0);

        await subject.incrementPrivateDnsTagChangeCounter(trace);
        expect(subject.privateDnsTagChangeCounter, 1);

        await subject.incrementPrivateDnsTagChangeCounter(trace);
        expect(subject.privateDnsTagChangeCounter, 2);
      });
    });
  });
}
