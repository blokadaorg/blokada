import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:common/common/module/api/api.dart';
import 'package:common/core/core.dart';
import 'package:common/platform/account/account.dart';
import 'package:common/platform/device/device.dart';
import 'package:common/platform/stage/stage.dart';
import 'package:common/plus/module/gateway/gateway.dart';
import 'package:common/plus/module/keypair/keypair.dart';
import 'package:common/util/cooldown.dart';

part 'actor.dart';
part 'api.dart';

class NoCurrentLeaseException implements Exception {}

class Lease {
  final String accountId;
  final String publicKey;
  final String gatewayId;
  final String expires;
  final String? alias;
  final String vip4;
  final String vip6;

  Lease({
    required this.accountId,
    required this.publicKey,
    required this.gatewayId,
    required this.expires,
    this.alias,
    required this.vip4,
    required this.vip6,
  });
}

mixin LeaseChannel {
  Future<void> doLeasesChanged(List<Lease> leases);
  Future<void> doCurrentLeaseChanged(Lease? lease);
}

class CurrentLeaseValue extends NullableAsyncValue<Lease> {
  CurrentLeaseValue() : super(sensitive: true);
}

class LeasesValue extends AsyncValue<List<Lease>> {
  LeasesValue() : super(sensitive: true) {
    load = (m) async => <Lease>[];
  }
}

class LeaseModule with Module {
  @override
  onCreateModule() async {
    await register(LeaseApi());
    await register(CurrentLeaseValue());
    await register(LeasesValue());
    await register(LeaseActor());
  }
}
