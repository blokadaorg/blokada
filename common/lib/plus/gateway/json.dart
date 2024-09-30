import 'dart:convert';

import 'package:common/logger/logger.dart';

import '../../http/http.dart';
import '../../json/json.dart';
import '../../util/di.dart';

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

class PlusGatewayJson {
  late final _http = dep<HttpService>();

  Future<List<JsonGateway>> get(Marker m) async {
    final result = await _http.get("$jsonUrl/v2/gateway", m);
    return JsonGatewayEndpoint.fromJson(jsonDecode(result)).gateways;
  }
}
