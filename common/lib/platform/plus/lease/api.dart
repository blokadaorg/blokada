import 'dart:convert';

import 'package:common/common/module/api/api.dart';
import 'package:common/core/core.dart';

import '../../device/device.dart';
import '../keypair/keypair.dart';

class TooManyLeasesException implements Exception {}

class JsonLeaseEndpoint {
  late List<JsonLease> leases;

  JsonLeaseEndpoint({required this.leases});

  JsonLeaseEndpoint.fromJson(Map<String, dynamic> json) {
    try {
      leases = <JsonLease>[];
      json['leases'].forEach((v) {
        leases.add(JsonLease.fromJson(v));
      });
    } on TypeError catch (e) {
      throw JsonError(json, e);
    } on NoSuchMethodError catch (e) {
      throw JsonError(json, e);
    }
  }
}

class JsonLease {
  late String accountId;
  late String publicKey;
  late String gatewayId;
  late String expires;
  late String? alias;
  late String vip4;
  late String vip6;

  JsonLease({
    required this.accountId,
    required this.publicKey,
    required this.gatewayId,
    required this.expires,
    this.alias,
    required this.vip4,
    required this.vip6,
  });

  JsonLease.fromJson(Map<String, dynamic> json) {
    try {
      accountId = json['account_id'];
      publicKey = json['public_key'];
      gatewayId = json['gateway_id'];
      expires = json['expires'];
      alias = json['alias'];
      vip4 = json['vip4'];
      vip6 = json['vip6'];
    } on TypeError catch (e) {
      throw JsonError(json, e);
    }
  }
}

class JsonLeasePayload {
  late String publicKey;
  late String gatewayId;
  late String? alias;

  JsonLeasePayload({
    required this.publicKey,
    required this.gatewayId,
    this.alias,
  });

  Map<String, dynamic> toJson() => {
        'account_id': ApiParam.accountId.placeholder,
        'public_key': publicKey,
        'gateway_id': gatewayId,
        'alias': alias,
      };
}

class PlusLeaseMarshal {
  List<JsonLease> toLeases(JsonString json) {
    return JsonLeaseEndpoint.fromJson(jsonDecode(json)).leases;
  }

  JsonString fromPayload(JsonLeasePayload payload) {
    return jsonEncode(payload.toJson());
  }

  JsonLease toLease(JsonString json) {
    return JsonLease.fromJson(jsonDecode(json)['lease']);
  }
}

class PlusLeaseApi {
  late final _api = Core.get<Api>();
  late final _keypair = Core.get<PlusKeypairStore>();
  late final _device = Core.get<DeviceStore>();
  late final _marshal = PlusLeaseMarshal();

  Future<List<JsonLease>> getLeases(Marker m, {bool noRetry = false}) async {
    final result = await _api.get(ApiEndpoint.getLeaseV2, m);
    // TODO: noRetry skipped

    return _marshal.toLeases(result);
  }

  Future<JsonLease> postLease(String gatewayId, Marker m) async {
    try {
      final payload = JsonLeasePayload(
        publicKey: _keypair.currentDevicePublicKey,
        gatewayId: gatewayId,
        alias: _device.deviceAlias,
      );

      final result = await _api.request(ApiEndpoint.postLeaseV2, m,
          payload: _marshal.fromPayload(payload));

      return _marshal.toLease(result);
    } on HttpCodeException catch (e) {
      if (e.code == 403) {
        throw TooManyLeasesException();
      } else {
        rethrow;
      }
    }
  }

  Future<void> deleteLeaseByGateway(String gatewayId, Marker m) async {
    final payload = JsonLeasePayload(
        publicKey: _keypair.currentDevicePublicKey, gatewayId: gatewayId);

    await _api.request(ApiEndpoint.deleteLeaseV2, m,
        payload: _marshal.fromPayload(payload));
  }

  Future<void> deleteLease(JsonLeasePayload payload, Marker m) async {
    await _api.request(ApiEndpoint.deleteLeaseV2, m,
        payload: _marshal.fromPayload(payload));
  }
}
