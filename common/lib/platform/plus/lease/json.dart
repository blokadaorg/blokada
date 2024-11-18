import 'dart:convert';

import 'package:common/core/core.dart';

import '../../account/account.dart';
import '../../device/device.dart';
import '../../http/http.dart';
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
  late String accountId;
  late String publicKey;
  late String gatewayId;
  late String? alias;

  JsonLeasePayload({
    required this.accountId,
    required this.publicKey,
    required this.gatewayId,
    this.alias,
  });

  Map<String, dynamic> toJson() => {
        'account_id': accountId,
        'public_key': publicKey,
        'gateway_id': gatewayId,
        'alias': alias,
      };
}

class PlusLeaseJson {
  late final _http = DI.get<HttpService>();
  late final _keypair = DI.get<PlusKeypairStore>();
  late final _account = DI.get<AccountStore>();
  late final _device = DI.get<DeviceStore>();

  Future<List<JsonLease>> getLeases(Marker m, {bool noRetry = false}) async {
    final result = await _http.get(
        '$jsonUrl/v2/lease?account_id=${_account.id}', m,
        noRetry: noRetry);
    return JsonLeaseEndpoint.fromJson(jsonDecode(result)).leases;
  }

  Future<JsonLease> postLease(String gatewayId, Marker m) async {
    try {
      final payload = JsonLeasePayload(
        accountId: _account.id,
        publicKey: _keypair.currentDevicePublicKey,
        gatewayId: gatewayId,
        alias: _device.deviceAlias,
      );

      final result = await _http.request('$jsonUrl/v2/lease', HttpType.post, m,
          payload: jsonEncode(payload.toJson()));
      return JsonLease.fromJson(jsonDecode(result)['lease']);
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
        accountId: _account.id,
        publicKey: _keypair.currentDevicePublicKey,
        gatewayId: gatewayId);

    await _http.request('$jsonUrl/v2/lease', HttpType.delete, m,
        payload: jsonEncode(payload.toJson()));
  }

  Future<void> deleteLease(JsonLeasePayload payload, Marker m) async {
    await _http.request('$jsonUrl/v2/lease', HttpType.delete, m,
        payload: jsonEncode(payload.toJson()));
  }
}
