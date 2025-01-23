import 'dart:convert';

import 'package:common/common/module/api/api.dart';
import 'package:common/core/core.dart';

class JsonGatewayEndpoint {
  late List<JsonGateway> gateways;

  JsonGatewayEndpoint({required this.gateways});

  JsonGatewayEndpoint.fromJson(Map<String, dynamic> json) {
    try {
      gateways = <JsonGateway>[];
      json['gateways'].forEach((v) {
        gateways.add(JsonGateway.fromJson(v));
      });
    } on TypeError catch (e) {
      throw JsonError(json, e);
    } on NoSuchMethodError catch (e) {
      throw JsonError(json, e);
    }
  }
}

class JsonGateway {
  late String publicKey;
  late String region;
  late String location;
  late int resourceUsagePercent;
  late String ipv4;
  late String ipv6;
  late int port;
  //late ActiveUntil expires;
  late List<String>? tags;
  late String? country;

  JsonGateway({
    required this.publicKey,
    required this.region,
    required this.location,
    required this.resourceUsagePercent,
    required this.ipv4,
    required this.ipv6,
    required this.port,
    //required this.expires,
    this.tags,
    this.country,
  });

  JsonGateway.fromJson(Map<String, dynamic> json) {
    try {
      publicKey = json['public_key'];
      region = json['region'];
      location = json['location'];
      resourceUsagePercent = json['resource_usage_percent'];
      ipv4 = json['ipv4'];
      ipv6 = json['ipv6'];
      port = json['port'];
      //expires = ActiveUntil.fromJson(json['expires']);
      tags = json['tags']?.cast<String>();
      country = json['country'];
    } on TypeError catch (e) {
      throw JsonError(json, e);
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['public_key'] = publicKey;
    data['region'] = region;
    data['location'] = location;
    data['resource_usage_percent'] = resourceUsagePercent;
    data['ipv4'] = ipv4;
    data['ipv6'] = ipv6;
    data['port'] = port;
    //data['expires'] = expires.toJson();
    data['tags'] = tags;
    data['country'] = country;
    return data;
  }
}

class PlusGatewayMarshal {
  List<JsonGateway> gateways(JsonString json) {
    return JsonGatewayEndpoint.fromJson(jsonDecode(json)).gateways;
  }
}

class PlusGatewayApi {
  late final _api = Core.get<Api>();
  late final _marshal = PlusGatewayMarshal();

  Future<List<JsonGateway>> get(Marker m) async {
    final result = await _api.get(ApiEndpoint.getGateways, m);
    return _marshal.gateways(result);
  }
}
