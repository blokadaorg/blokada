import 'package:common/core/core.dart';
import 'package:common/dragon/family/family.dart';
import 'package:common/lock/value.dart';
import 'package:common/platform/account/account.dart';
import 'package:common/platform/env/env.dart';
import 'package:common/platform/link/channel.pg.dart';
import 'package:common/platform/link/link.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../tools.dart';
@GenerateNiceMocks([
  MockSpec<LinkOps>(),
  MockSpec<AccountStore>(),
  MockSpec<IsLocked>(),
  MockSpec<EnvStore>(),
  MockSpec<FamilyStore>(),
])
import 'link_test.mocks.dart';

void main() {
  group("store", () {
    test("willUpdateLinksOnLock", () async {
      await withTrace((m) async {
        DI.register<AccountStore>(MockAccountStore());
        DI.register<FamilyStore>(MockFamilyStore());
        DI.register<IsLocked>(MockIsLocked());

        final env = MockEnvStore();
        when(env.userAgent).thenReturn("mocked user agent");
        DI.register<EnvStore>(env);

        final ops = MockLinkOps();
        DI.register<LinkOps>(ops);

        final subject = LinkStore();
        mockAct(subject);
        subject.start(m);

        await subject.updateLinksFromLock(true);

        verify(ops.doLinksChanged(any)).called(1);
      });
    });
  });
}
