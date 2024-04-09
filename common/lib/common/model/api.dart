part of '../model.dart';

typedef QueryParams = Map<ApiParam, String>;
typedef Headers = Map<String, String>;

class HttpRequest {
  final ApiEndpoint endpoint;
  final int retries;
  String? payload;
  late String url;
  late Headers headers;

  HttpRequest(
    this.endpoint, {
    this.payload,
    this.retries = 2,
  });
}

enum ApiEndpoint {
  getGateways("v2/gateway"),
  getLists("v2/list", params: [ApiParam.accountId]),
  getProfiles("v3/profile", params: [ApiParam.accountId]),
  postProfile("v3/profile", type: "POST", params: [ApiParam.accountId]),
  putProfile("v3/profile", type: "PUT", params: [ApiParam.accountId]),
  deleteProfile("v3/profile", type: "DELETE", params: [ApiParam.accountId]),
  getDevices("v3/device", params: [ApiParam.accountId]),
  getDevicesByToken("v3/device", params: [ApiParam.deviceTag]),
  postDevice("v3/device", type: "POST", params: [ApiParam.accountId]),
  putDevice("v3/device", type: "PUT", params: [ApiParam.accountId]),
  deleteDevice("v3/device", type: "DELETE", params: [ApiParam.accountId]),
  postHeartbeat("v3/device/heartbeat", type: "POST"),
  getStats("v3/stats", params: [
    ApiParam.accountId,
    ApiParam.deviceTag,
    ApiParam.statsSince,
    ApiParam.statsDownsample,
  ]),
  getJournal("v3/activity", params: [
    ApiParam.accountId,
    ApiParam.deviceTag,
  ]),
  postToken("v3/auth/token", type: "POST"),
  postTokenRefresh("v3/auth/token/refresh", type: "POST"),
  getTokenInfo("v3/auth/token/info");

  const ApiEndpoint(
    this.endpoint, {
    this.type = "GET",
    this.params = const [],
  });

  final String endpoint;
  final String type;
  final List<ApiParam> params;

  String get template => endpoint + getParams;

  String get getParams {
    if (params.isEmpty) return "";
    if (type != "GET") return "";
    final p = params.map((e) => "${e.name}=${e.placeholder}").join("&");
    return "?$p";
  }
}

enum ApiParam {
  accountId("account_id"),
  deviceTag("device_tag"),
  statsSince("since"),
  statsDownsample("downsample");

  const ApiParam(this.name) : placeholder = "($name)";

  final String name;
  final String placeholder;
}
