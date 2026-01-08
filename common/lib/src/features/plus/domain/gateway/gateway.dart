import 'dart:convert';

import 'package:common/src/features/api/domain/api.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/platform/stage/channel.pg.dart';
import 'package:common/src/platform/stage/stage.dart';
import 'package:common/src/util/cooldown.dart';
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

  @override
  String toString() {
    return "Gateway(publicKey: $publicKey, region: $region, location: $location, "
        "resourceUsagePercent: $resourceUsagePercent, ipv4: $ipv4, ipv6: $ipv6, "
        "port: $port, country: $country)";
  }
}

typedef GatewayId = String;

class CurrentGatewayIdValue extends StringPersistedValue {
  CurrentGatewayIdValue() : super("gateway:jsonSelectedGateway");
}

class CurrentGatewayValue extends NullableAsyncValue<Gateway> {
  CurrentGatewayValue() : super(sensitive: true);
}

class GatewaysValue extends NullableAsyncValue<List<Gateway>> {
  GatewaysValue() : super(sensitive: true);
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
    await register(GatewaysValue());
    await register(GatewayActor());
  }
}
