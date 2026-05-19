import 'package:common/src/core/core.dart';
import 'package:common/src/features/payment/domain/payment.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tools.dart';

class _FakeReferrerChannel implements InstallReferrerChannel {
  String? url;
  bool throwOnFetch = false;

  @override
  Future<String?> fetchReferrerUrl() async {
    if (throwOnFetch) throw Exception('referrer boom');
    return url;
  }
}

class _FakePaymentChannel implements PaymentChannel {
  final attributionMaps = <Map<String, dynamic>>[];
  final attributionSources = <String>[];
  final customAttrCalls = <Map<String, dynamic>>[];
  bool throwOnUpdateAttribution = false;

  @override
  Future<void> updateAttribution(Marker m, Map<String, dynamic> attribution,
      {String source = "custom"}) async {
    if (throwOnUpdateAttribution) throw Exception('adapty unavailable');
    attributionMaps.add(attribution);
    attributionSources.add(source);
  }

  @override
  Future<void> setCustomAttributes(
      Marker m, Map<String, dynamic> attributes) async {
    customAttrCalls.add(attributes);
  }

  @override
  Future<void> init(
      Marker m, String apiKey, String? accountId, bool verboseLogs) async {}
  @override
  Future<void> identify(String accountId) async {}
  @override
  Future<void> logOnboardingStep(String name, OnboardingStep step) async {}
  @override
  Future<void> preload(Marker m, Placement placement) async {}
  @override
  Future<void> showPaymentScreen(Marker m, Placement placement,
      {bool forceReload = false}) async {}
  @override
  Future<void> closePaymentScreen(bool isError) async {}
}

typedef _Ctx = ({
  _FakeReferrerChannel ref,
  _FakePaymentChannel pay,
  InstallReferrerSentValue guard,
  InstallReferrerService svc,
});

Future<_Ctx> _setup({required bool android}) async {
  Core.act = ActScreenplay(ActScenario.test, Flavor.v6,
      android ? PlatformType.android : PlatformType.iOS);
  Core.register<Persistence>(Persistence(isSecure: false));
  Core.register<Persistence>(Persistence(isSecure: true),
      tag: Persistence.secure);

  final ref = _FakeReferrerChannel();
  final pay = _FakePaymentChannel();
  final guard = InstallReferrerSentValue();
  Core.register<InstallReferrerChannel>(ref);
  Core.register<PaymentChannel>(pay);
  Core.register(guard);

  return (ref: ref, pay: pay, guard: guard, svc: InstallReferrerService());
}

void main() {
  group('InstallReferrerService', () {
    test('sends Google Ads attribution + gclid once, then guards', () async {
      await withTrace((m) async {
        final c = await _setup(android: true);
        c.ref.url = 'gclid=G1&utm_source=google&utm_medium=cpc'
            '&utm_campaign=summer';

        await c.svc.sendAttributionOnce(m);

        expect(c.pay.attributionMaps, hasLength(1));
        expect(c.pay.attributionSources.single, 'custom');
        expect(c.pay.attributionMaps.single['status'], 'non_organic');
        expect(c.pay.attributionMaps.single['channel'], 'google');
        expect(c.pay.attributionMaps.single['campaign'], 'summer');
        expect(c.pay.customAttrCalls, hasLength(1));
        final attrs = c.pay.customAttrCalls.single['custom_attributes']
            as List<Map<String, dynamic>>;
        expect(attrs.any((a) => a['key'] == 'acq_gclid' && a['value'] == 'G1'),
            isTrue);
        expect(await c.guard.now(), isTrue);

        // Second call is a no-op (idempotent).
        await c.svc.sendAttributionOnce(m);
        expect(c.pay.attributionMaps, hasLength(1));
      });
    });

    test('does nothing when the guard is already set', () async {
      await withTrace((m) async {
        final c = await _setup(android: true);
        await c.guard.change(m, true);
        c.ref.url = 'gclid=G&utm_medium=cpc';

        await c.svc.sendAttributionOnce(m);

        expect(c.pay.attributionMaps, isEmpty);
        expect(c.pay.customAttrCalls, isEmpty);
      });
    });

    test('referrer unavailable -> organic sent, guard set, no spin', () async {
      await withTrace((m) async {
        final c = await _setup(android: true);
        c.ref.url = null;

        await c.svc.sendAttributionOnce(m);

        expect(c.pay.attributionMaps, hasLength(1));
        expect(c.pay.attributionMaps.single['status'], 'organic');
        expect(await c.guard.now(), isTrue);
      });
    });

    test('transient updateAttribution error: no rethrow, guard unset, retries',
        () async {
      await withTrace((m) async {
        final c = await _setup(android: true);
        c.ref.url = 'gclid=G&utm_medium=cpc';
        c.pay.throwOnUpdateAttribution = true;

        // Must not throw into the startup sequence.
        await c.svc.sendAttributionOnce(m);
        expect(await c.guard.now(), isFalse);

        // Next app start retries successfully.
        c.pay.throwOnUpdateAttribution = false;
        await c.svc.sendAttributionOnce(m);
        expect(c.pay.attributionMaps, hasLength(1));
        expect(await c.guard.now(), isTrue);
      });
    });

    test('iOS is gated: never calls Adapty (protects Apple Search Ads)',
        () async {
      await withTrace((m) async {
        final c = await _setup(android: false);
        c.ref.url = 'gclid=G&utm_source=google&utm_medium=cpc';

        await c.svc.sendAttributionOnce(m);

        expect(c.pay.attributionMaps, isEmpty);
        expect(c.pay.customAttrCalls, isEmpty);
        expect(await c.guard.now(), isFalse);
      });
    });
  });
}
