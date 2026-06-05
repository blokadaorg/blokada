import 'package:common/src/features/api/domain/api.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/platform/perm/dnscheck.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../tools.dart';
@GenerateNiceMocks([
  MockSpec<Api>(),
])
import 'dnscheck_test.mocks.dart';

void main() {
  group("getDnsOwnerFlavor", () {
    test("returns the owning flavor when Blokada DNS is active", () async {
      await withTrace((m) async {
        final api = MockApi();
        when(api.request(any, any,
                skipResolvingParams: anyNamed("skipResolvingParams"),
                attempts: anyNamed("attempts")))
            .thenAnswer((_) => Future.value('{"blokada_dns":true,"flavor":"plus"}'));
        Core.register<Api>(api);

        final flavor = await PrivateDnsCheck().getDnsOwnerFlavor(m);

        expect(flavor, "plus");
        // The untagged endpoint must be queried without resolving the account,
        // so detection works during onboarding before a Family account exists.
        verify(api.request(ApiEndpoint.getStatusTestNoTag, any,
                skipResolvingParams: true, attempts: 1))
            .called(1);
      });
    });

    test("returns null when DNS is not routed through Blokada", () async {
      await withTrace((m) async {
        final api = MockApi();
        when(api.request(any, any,
                skipResolvingParams: anyNamed("skipResolvingParams"),
                attempts: anyNamed("attempts")))
            .thenAnswer((_) => Future.value('{"blokada_dns":false}'));
        Core.register<Api>(api);

        final flavor = await PrivateDnsCheck().getDnsOwnerFlavor(m);

        expect(flavor, null);
      });
    });
  });
}
