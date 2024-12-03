import 'package:common/common/module/lock/lock.dart';
import 'package:common/core/core.dart';
import 'package:common/family/module/family/family.dart';
import 'package:common/platform/account/account.dart';
import 'package:common/platform/env/env.dart';
import 'package:common/platform/link/channel.pg.dart';
import 'package:common/platform/link/link.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../tools.dart';
@GenerateNiceMocks([
  MockSpec<LinkOps>(),
  MockSpec<AccountStore>(),
  MockSpec<IsLocked>(),
  MockSpec<EnvStore>(),
  MockSpec<FamilyActor>(),
])
import 'link_test.mocks.dart';

void main() {
  group("store", () {
    test("willUpdateLinksOnLock", () async {
      await withTrace((m) async {
        Core.register<AccountStore>(MockAccountStore());
        Core.register<FamilyActor>(MockFamilyActor());
        Core.register<IsLocked>(MockIsLocked());

        final env = MockEnvStore();
        when(env.userAgent).thenReturn("mocked user agent");
        Core.register<EnvStore>(env);

        final ops = MockLinkOps();
        Core.register<LinkOps>(ops);

        final subject = LinkStore();
        mockAct(subject);
        subject.start(m);

        await subject
            .updateLinksFromLock(ValueUpdate(Markers.testing, false, true));

        verify(ops.doLinksChanged(any)).called(1);
      });
    });
  });
}
