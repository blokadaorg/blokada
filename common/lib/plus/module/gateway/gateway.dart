import 'dart:convert';

import 'package:common/common/module/api/api.dart';
import 'package:common/core/core.dart';
import 'package:common/platform/stage/channel.pg.dart';
import 'package:common/platform/stage/stage.dart';
import 'package:common/util/cooldown.dart';
import 'package:dartx/dartx.dart';

part 'actor.dart';
part 'api.dart';

class Gateway {
  final String publicKey;
  final String region;
  final String location;
  final int resourceUsagePercent;
  final String ipv4;
  final String ipv6;
  final int port;
  final String? country;

  Gateway(this.publicKey, this.region, this.location, this.resourceUsagePercent,
      this.ipv4, this.ipv6, this.port, this.country);

  // Location with capitalized each word
  String get niceName => location
      .split("-")
      .map((it) => it[0].toUpperCase() + it.substring(1))
      .join(" ");
}

typedef GatewayId = String;

class CurrentGatewayIdValue extends StringPersistedValue {
  CurrentGatewayIdValue() : super("gateway:jsonSelectedGateway");
}

class CurrentGatewayValue extends NullableAsyncValue<Gateway> {
  CurrentGatewayValue() : super (sensitive: true);
}

@PlatformProvided()
mixin GatewayChannel {
  Future<void> doGatewaysChanged(List<Gateway> gateways);
  Future<void> doSelectedGatewayChanged(GatewayId? publicKey);
}

class GatewayModule with Module {
  @override
  onCreateModule() async {
    await register(GatewayApi());
    await register(CurrentGatewayIdValue());
    await register(CurrentGatewayValue());
    await register(GatewayActor());
  }
}
