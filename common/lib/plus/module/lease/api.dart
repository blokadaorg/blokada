part of 'lease.dart';

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

  Lease get toLease => Lease(
        accountId: accountId,
        publicKey: publicKey,
        gatewayId: gatewayId,
        expires: expires,
        alias: alias,
        vip4: vip4,
        vip6: vip6,
      );
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

class LeaseApi {
  late final _api = Core.get<Api>();
  late final _marshal = PlusLeaseMarshal();

  Future<List<JsonLease>> getLeases(Marker m, {bool noRetry = false}) async {
    final result = await _api.get(ApiEndpoint.getLeaseV2, m);
    // TODO: noRetry skipped

    return _marshal.toLeases(result);
  }

  Future<JsonLease> postLease(Marker m, String deviceAlias,
      String keypairPublicKey, String gatewayId) async {
    try {
      final payload = JsonLeasePayload(
        publicKey: keypairPublicKey,
        gatewayId: gatewayId,
        alias: deviceAlias,
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

  Future<void> deleteLease(JsonLeasePayload payload, Marker m) async {
    await _api.request(ApiEndpoint.deleteLeaseV2, m,
        payload: _marshal.fromPayload(payload));
  }
}
