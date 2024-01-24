import 'dart:convert';

import 'package:common/env/env.dart';

import '../../account/account.dart';
import '../../device/device.dart';
import '../../http/http.dart';
import '../../json/json.dart';
import '../../util/di.dart';
import '../../util/trace.dart';
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
  late final _http = dep<HttpService>();
  late final _keypair = dep<PlusKeypairStore>();
  late final _account = dep<AccountStore>();
  late final _device = dep<DeviceStore>();

  Future<List<JsonLease>> getLeases(Trace trace, {bool noRetry = false}) async {
    final result = await _http.get(
        trace, '$jsonUrl/v2/lease?account_id=${_account.id}',
        noRetry: noRetry);
    return JsonLeaseEndpoint.fromJson(jsonDecode(result)).leases;
  }

  Future<JsonLease> postLease(Trace trace, String gatewayId) async {
    try {
      final payload = JsonLeasePayload(
        accountId: _account.id,
        publicKey: _keypair.currentDevicePublicKey,
        gatewayId: gatewayId,
        alias: _device.deviceAlias,
      );

      final result = await _http.request(
          trace, '$jsonUrl/v2/lease', HttpType.post,
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

  Future<void> deleteLeaseByGateway(Trace trace, String gatewayId) async {
    final payload = JsonLeasePayload(
        accountId: _account.id,
        publicKey: _keypair.currentDevicePublicKey,
        gatewayId: gatewayId);

    await _http.request(trace, '$jsonUrl/v2/lease', HttpType.delete,
        payload: jsonEncode(payload.toJson()));
  }

  Future<void> deleteLease(Trace trace, JsonLeasePayload payload) async {
    await _http.request(trace, '$jsonUrl/v2/lease', HttpType.delete,
        payload: jsonEncode(payload.toJson()));
  }
}
