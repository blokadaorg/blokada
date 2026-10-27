import 'package:common/src/app_variants/family/module/perm/perm.dart';
import 'package:common/src/features/private_dns/domain/private_dns_setup.dart';
import 'package:common/src/platform/perm/channel.pg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter/services.dart';

/// Returns a fixed Private DNS state, as the native side would.
class FakeDnsChannel with PermChannel {
  PrivateDnsState state;
  var openSettingsCalls = 0;
  var failOpenSettings = false;

  FakeDnsChannel(this.state);

  @override
  Future<PrivateDnsState> getPrivateDnsState() async => state;

  @override
  Future<void> doOpenPermSettings() async {
    openSettingsCalls++;
    if (failOpenSettings) throw PlatformException(code: "Exception");
  }

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

PrivateDnsState dnsState(String? host, {bool? broken}) => PrivateDnsState(
  kind: host == null ? PrivateDnsStateKind.disabled : PrivateDnsStateKind.enabled,
  serverUrl: host,
  privateDnsBroken: broken,
);

const _tag = "abc123";

void main() {
  Future<PrivateDnsSetupStep> run(PrivateDnsState state) {
    return PrivateDnsSetupVerifier(channel: FakeDnsChannel(state)).verify(_tag);
  }

  group("verify", () {
    test("Private DNS off shows the setup steps", () async {
      expect(await run(dnsState(null)), PrivateDnsSetupStep.setup);
    });

    test("matching hostname is success", () async {
      expect(await run(dnsState(" PIXEL-ABC123.cloud.blokada.org. ")), PrivateDnsSetupStep.success);
    });

    test("family form counts as a match", () async {
      expect(await run(dnsState("abc123.cloud.blokada.org")), PrivateDnsSetupStep.success);
    });

    test("a broken flag does not override a matching hostname", () async {
      expect(
        await run(dnsState("pixel-abc123.cloud.blokada.org", broken: true)),
        PrivateDnsSetupStep.success,
      );
    });

    test("another device's Blokada hostname shows the setup steps", () async {
      expect(await run(dnsState("pixel-abc124.cloud.blokada.org")), PrivateDnsSetupStep.setup);
    });

    test("another provider shows the setup steps", () async {
      expect(await run(dnsState("dns.example.com")), PrivateDnsSetupStep.setup);
    });

    test("a hostname with Private DNS off shows the setup steps", () async {
      final state = PrivateDnsState(
        kind: PrivateDnsStateKind.disabled,
        serverUrl: "pixel-abc123.cloud.blokada.org",
      );
      expect(await run(state), PrivateDnsSetupStep.setup);
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
