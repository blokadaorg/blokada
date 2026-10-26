import 'package:common/src/app_variants/family/module/perm/perm.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/features/private_dns/domain/private_dns_setup.dart';
import 'package:common/src/platform/perm/channel.pg.dart';
import 'package:common/src/platform/perm/dnscheck.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tools.dart';

/// Returns a fixed Private DNS state, as the native side would.
class FakeDnsChannel with PermChannel {
  PrivateDnsState state;
  var openSettingsCalls = 0;

  FakeDnsChannel(this.state);

  @override
  Future<PrivateDnsState> getPrivateDnsState() async => state;

  @override
  Future<void> doOpenPermSettings() async => openSettingsCalls++;

  @override
  Future<bool> doAuthenticate() async => true;

  @override
  Future<void> doAskNotificationPerms() async {}

  @override
  Future<void> doAskVpnPerms() async {}

  @override
  Future<bool> doNotificationEnabled() async => true;

  @override
  Future<void> doSetDns(String tag) async {}

  @override
  Future<void> doSetPrivateDnsEnabled(String tag, String alias) async {}

  @override
  Future<bool> doVpnEnabled() async => false;

  @override
  Future<bool> isRunningOnMac() async => false;
}

/// Answers the live probe from a script instead of the network.
class FakeOwnerCheck extends PrivateDnsCheck {
  final List<Object?> answers;
  var probes = 0;

  FakeOwnerCheck(this.answers);

  @override
  Future<String?> getDnsOwnerFlavor(Marker m, {bool fresh = false}) async {
    final answer = answers[probes < answers.length ? probes : answers.length - 1];
    probes++;
    if (answer is Exception) throw answer;
    return answer as String?;
  }
}

PrivateDnsState dnsState(String? host, {bool? broken}) => PrivateDnsState(
  kind: host == null ? PrivateDnsStateKind.disabled : PrivateDnsStateKind.enabled,
  serverUrl: host,
  privateDnsBroken: broken,
);

const _tag = "abc123";
const _ours = "pixel-abc123.cloud.blokada.org";

void main() {
  Future<PrivateDnsSetupResult> run(
    Marker m,
    PrivateDnsState state, {
    List<Object?> probe = const ["cloud"],
    bool attempted = true,
    FakeOwnerCheck? check,
  }) {
    final verifier = PrivateDnsSetupVerifier(
      channel: FakeDnsChannel(state),
      check: check ?? FakeOwnerCheck(probe),
      probeDelay: Duration.zero,
    );
    return verifier.verify(m, _tag, attempted: attempted);
  }

  group("verify", () {
    test("Private DNS off shows the setup steps", () async {
      await withTrace((m) async {
        final r = await run(m, dnsState(null));
        expect(r.step, PrivateDnsSetupStep.setup);
      });
    });

    test("matching hostname and live probe show success", () async {
      await withTrace((m) async {
        var checking = false;
        final verifier = PrivateDnsSetupVerifier(
          channel: FakeDnsChannel(dnsState(" PIXEL-ABC123.cloud.blokada.org. ")),
          check: FakeOwnerCheck(["cloud"]),
          probeDelay: Duration.zero,
        );
        final r = await verifier.verify(
          m,
          _tag,
          attempted: true,
          onChecking: () => checking = true,
        );
        expect(r.step, PrivateDnsSetupStep.success);
        expect(checking, isTrue);
      });
    });

    test("family form counts as a match", () async {
      await withTrace((m) async {
        final r = await run(m, dnsState("abc123.cloud.blokada.org"), probe: ["family"]);
        expect(r.step, PrivateDnsSetupStep.success);
      });
    });

    test("probe retries while Android validates the server", () async {
      await withTrace((m) async {
        final check = FakeOwnerCheck([Exception("lookup failed"), null, "plus"]);
        final r = await run(m, dnsState(_ours), check: check);
        expect(r.step, PrivateDnsSetupStep.success);
        expect(check.probes, 3);
      });
    });

    test("hostname matches but DNS is not routed shows help", () async {
      await withTrace((m) async {
        final check = FakeOwnerCheck([null]);
        final r = await run(m, dnsState(_ours), check: check);
        expect(r.step, PrivateDnsSetupStep.help);
        expect(r.reason, PrivateDnsHelpReason.notRouted);
        expect(check.probes, 3);
      });
    });

    test("unreachable Private DNS shows help when the probe fails", () async {
      await withTrace((m) async {
        final check = FakeOwnerCheck([Exception("lookup failed")]);
        final r = await run(m, dnsState(_ours, broken: true), check: check);
        expect(r.step, PrivateDnsSetupStep.help);
        expect(r.reason, PrivateDnsHelpReason.broken);
      });
    });

    test("a stale broken flag does not override a working probe", () async {
      await withTrace((m) async {
        final r = await run(m, dnsState(_ours, broken: true), probe: ["cloud"]);
        expect(r.step, PrivateDnsSetupStep.success);
      });
    });

    test("another tag after going to Settings shows help", () async {
      await withTrace((m) async {
        final r = await run(m, dnsState("pixel-abc124.cloud.blokada.org"));
        expect(r.step, PrivateDnsSetupStep.help);
        expect(r.reason, PrivateDnsHelpReason.wrongHostname);
      });
    });

    test("a mistyped Blokada hostname shows help even before Settings", () async {
      await withTrace((m) async {
        final r = await run(m, dnsState("pixel-abc12.cloud.blokada.org"), attempted: false);
        expect(r.step, PrivateDnsSetupStep.help);
      });
    });

    test("another provider before Settings shows the setup steps", () async {
      await withTrace((m) async {
        final r = await run(m, dnsState("dns.example.com"), attempted: false);
        expect(r.step, PrivateDnsSetupStep.setup);
      });
    });
  });

  group("privateDnsOemFor", () {
    test("maps manufacturers", () {
      expect(privateDnsOemFor("samsung"), PrivateDnsOem.samsung);
      expect(privateDnsOemFor("Xiaomi"), PrivateDnsOem.xiaomi);
      expect(privateDnsOemFor("Redmi"), PrivateDnsOem.xiaomi);
      expect(privateDnsOemFor("POCO"), PrivateDnsOem.xiaomi);
      expect(privateDnsOemFor("Google"), PrivateDnsOem.pixel);
      expect(privateDnsOemFor("OnePlus"), PrivateDnsOem.oneplus);
      expect(privateDnsOemFor("motorola"), PrivateDnsOem.other);
      expect(privateDnsOemFor(null), PrivateDnsOem.other);
    });
  });
}
