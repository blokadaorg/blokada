import 'package:common/src/core/core.dart';
import 'package:common/src/features/payment/domain/payment.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tools.dart';

class _FakeReferrerChannel implements InstallReferrerChannel {
  InstallReferrerFetchResult result = const InstallReferrerFetchResult(
      InstallReferrerFetchStatus.permanentlyUnavailable);

  void ok(String? url) =>
      result = InstallReferrerFetchResult(InstallReferrerFetchStatus.ok, url);

  @override
  Future<InstallReferrerFetchResult> fetchReferrer() async => result;
}

class _FakePaymentChannel implements PaymentChannel {
  final attributionMaps = <Map<String, dynamic>>[];
  final attributionSources = <String>[];
  final customAttrCalls = <Map<String, dynamic>>[];
  bool throwOnUpdateAttribution = false;
  bool throwOnSetCustomAttributes = false;

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
    customAttrCalls.add(attributes); // record the attempt, then maybe fail
    if (throwOnSetCustomAttributes) throw Exception('custom attrs failed');
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
        c.ref.ok('gclid=G1&utm_source=google&utm_medium=cpc'
            '&utm_campaign=summer');

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
        c.ref.ok('gclid=G&utm_medium=cpc');

        await c.svc.sendAttributionOnce(m);

        expect(c.pay.attributionMaps, isEmpty);
        expect(c.pay.customAttrCalls, isEmpty);
      });
    });

    test('permanently unavailable -> organic sent, guard set, no spin',
        () async {
      await withTrace((m) async {
        final c = await _setup(android: true);
        c.ref.result = const InstallReferrerFetchResult(
            InstallReferrerFetchStatus.permanentlyUnavailable);

        await c.svc.sendAttributionOnce(m);

        expect(c.pay.attributionMaps, hasLength(1));
        expect(c.pay.attributionMaps.single['status'], 'organic');
        expect(await c.guard.now(), isTrue);
      });
    });

    test(
        'transiently unavailable -> nothing sent, guard unset, retries next '
        'start (no permanent organic misattribution)', () async {
      await withTrace((m) async {
        final c = await _setup(android: true);
        c.ref.result = const InstallReferrerFetchResult(
            InstallReferrerFetchStatus.transientlyUnavailable);

        await c.svc.sendAttributionOnce(m);

        expect(c.pay.attributionMaps, isEmpty);
        expect(c.pay.customAttrCalls, isEmpty);
        expect(await c.guard.now(), isFalse);

        // Next app start: Play is reachable, the real campaign is captured.
        c.ref.ok('gclid=G9&utm_source=google&utm_medium=cpc');
        await c.svc.sendAttributionOnce(m);

        expect(c.pay.attributionMaps, hasLength(1));
        expect(c.pay.attributionMaps.single['status'], 'non_organic');
        expect(await c.guard.now(), isTrue);
      });
    });

    test('transient updateAttribution error: no rethrow, guard unset, retries',
        () async {
      await withTrace((m) async {
        final c = await _setup(android: true);
        c.ref.ok('gclid=G&utm_medium=cpc');
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

    test(
        'setCustomAttributes failure after updateAttribution succeeds: guard '
        'still set, no rethrow, not re-attempted', () async {
      await withTrace((m) async {
        final c = await _setup(android: true);
        c.ref.ok('gclid=G&utm_source=google&utm_medium=cpc');
        c.pay.throwOnSetCustomAttributes = true;

        await c.svc.sendAttributionOnce(m);

        // Attribution delivered + checkpointed despite the best-effort
        // custom-attribute write failing (decoupled).
        expect(c.pay.attributionMaps, hasLength(1));
        expect(c.pay.customAttrCalls, hasLength(1)); // attempted
        expect(await c.guard.now(), isTrue);

        // Next start does NOT re-attempt updateAttribution (Adapty is
        // one-source-per-profile) nor wedge.
        c.pay.throwOnSetCustomAttributes = false;
        await c.svc.sendAttributionOnce(m);
        expect(c.pay.attributionMaps, hasLength(1));
      });
    });

    test('iOS is gated: never calls Adapty (protects Apple Search Ads)',
        () async {
      await withTrace((m) async {
        final c = await _setup(android: false);
        c.ref.ok('gclid=G&utm_source=google&utm_medium=cpc');

        await c.svc.sendAttributionOnce(m);

        expect(c.pay.attributionMaps, isEmpty);
        expect(c.pay.customAttrCalls, isEmpty);
        expect(await c.guard.now(), isFalse);
      });
    });
  });
}
