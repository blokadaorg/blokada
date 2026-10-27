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
  group("isAndroidHostnameForTag", () {
    const tag = "abc123";
    final match = PrivateDnsCheck.isAndroidHostnameForTag;

    test("accepts the alias form with any alias", () {
      expect(match("Pixel-8-abc123.cloud.blokada.org", tag), isTrue);
      expect(match("my--phone-abc123.cloud.blokada.org", tag), isTrue);
      expect(match("x-abc123.cloud.blokada.org", tag), isTrue);
    });

    test("accepts the family form", () {
      expect(match("abc123.cloud.blokada.org", tag), isTrue);
    });

    test("ignores case, spaces and a trailing dot", () {
      expect(match("  PIXEL-ABC123.Cloud.Blokada.ORG.  ", tag), isTrue);
      expect(match("abc123.cloud.blokada.org.", "ABC123"), isTrue);
    });

    test("rejects another tag", () {
      expect(match("pixel-abc124.cloud.blokada.org", tag), isFalse);
      expect(match("abc1234.cloud.blokada.org", tag), isFalse);
      expect(match("pixel-xabc123.cloud.blokada.org", tag), isFalse);
      expect(match("abc123-pixel.cloud.blokada.org", tag), isFalse);
    });

    test("rejects malformed and foreign hostnames", () {
      expect(match("-abc123.cloud.blokada.org", tag), isFalse);
      expect(match("cloud.blokada.org", tag), isFalse);
      expect(match("abc123.cloud.blokada.org.evil.com", tag), isFalse);
      expect(match("abc123.dns.adguard.com", tag), isFalse);
      expect(match("", tag), isFalse);
      expect(match("abc123.cloud.blokada.org", ""), isFalse);
    });
  });

  group("isCorrect", () {
    test("on Android accepts a hand-typed hostname for the tag", () async {
      await withTrace((m) async {
        Core.act = ActScreenplay(ActScenario.test, Flavor.v6, PlatformType.android);
        final check = PrivateDnsCheck();
        expect(check.isCorrect(m, "Typed-abc123.cloud.blokada.org", "abc123", "Pixel"), isTrue);
        expect(check.isCorrect(m, "abc123.cloud.blokada.org", "abc123", "Pixel"), isTrue);
        expect(check.isCorrect(m, "pixel-other1.cloud.blokada.org", "abc123", "Pixel"), isFalse);
      });
    });

    test("on Family Android accepts the family form", () async {
      await withTrace((m) async {
        Core.act = ActScreenplay(ActScenario.test, Flavor.family, PlatformType.android);
        final check = PrivateDnsCheck();
        expect(check.isCorrect(m, "ABC123.cloud.blokada.org", "abc123", "Pixel"), isTrue);
      });
    });

    test("on iOS stays an exact match", () async {
      await withTrace((m) async {
        final check = PrivateDnsCheck();
        expect(check.isCorrect(m, "https://cloud.blokada.org/abc123/iPhone", "abc123", "iPhone"),
            isTrue);
        expect(check.isCorrect(m, "https://cloud.blokada.org/abc123/Other", "abc123", "iPhone"),
            isFalse);
        expect(check.isCorrect(m, "https://cloud.blokada.org/ABC123/iPhone", "abc123", "iPhone"),
            isFalse);
      });
    });
  });

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

    test("treats a non-string flavor as not-owned instead of throwing", () async {
      await withTrace((m) async {
        final api = MockApi();
        when(api.request(any, any,
                skipResolvingParams: anyNamed("skipResolvingParams"),
                attempts: anyNamed("attempts")))
            .thenAnswer((_) => Future.value('{"blokada_dns":true,"flavor":1}'));
        Core.register<Api>(api);

        final flavor = await PrivateDnsCheck().getDnsOwnerFlavor(m);

        expect(flavor, null);
      });
    });

    test("memoizes within the cache window so a second call hits no network", () async {
      await withTrace((m) async {
        final api = MockApi();
        when(api.request(any, any,
                skipResolvingParams: anyNamed("skipResolvingParams"),
                attempts: anyNamed("attempts")))
            .thenAnswer((_) => Future.value('{"blokada_dns":true,"flavor":"plus"}'));
        Core.register<Api>(api);

        final subject = PrivateDnsCheck();
        expect(await subject.getDnsOwnerFlavor(m), "plus");
        expect(await subject.getDnsOwnerFlavor(m), "plus");

        verify(api.request(any, any,
                skipResolvingParams: anyNamed("skipResolvingParams"),
                attempts: anyNamed("attempts")))
            .called(1);
      });
    });

    test("shares one in-flight request across concurrent callers", () async {
      await withTrace((m) async {
        final api = MockApi();
        when(api.request(any, any,
                skipResolvingParams: anyNamed("skipResolvingParams"),
                attempts: anyNamed("attempts")))
            .thenAnswer((_) async => '{"blokada_dns":true,"flavor":"cloud"}');
        Core.register<Api>(api);

        final subject = PrivateDnsCheck();
        final results = await Future.wait([
          subject.getDnsOwnerFlavor(m),
          subject.getDnsOwnerFlavor(m),
        ]);

        expect(results, ["cloud", "cloud"]);
        verify(api.request(any, any,
                skipResolvingParams: anyNamed("skipResolvingParams"),
                attempts: anyNamed("attempts")))
            .called(1);
      });
    });
  });
}
