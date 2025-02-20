part of 'api.dart';

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
  // V3 api
  getGateways("v2/gateway"),
  getLists("v3/list", params: [ApiParam.accountId]),
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
  getTokenInfo("v3/auth/token/info"),
  getCustomList("v3/customlist", params: [
    ApiParam.accountId,
    ApiParam.profileId,
  ]),
  postCustomList("v3/customlist", type: "POST", params: [ApiParam.accountId]),
  deleteCustomList("v3/customlist",
      type: "DELETE", params: [ApiParam.accountId]),
  postSupport("https://support.blocka.net/v3/support",
      type: "POST", params: [ApiParam.accountId, ApiParam.userAgent]),
  getSupport("https://support.blocka.net/v3/support",
      type: "GET", params: [ApiParam.sessionId]),
  putSupport("https://support.blocka.net/v3/support", type: "PUT"),
  postAdaptyCheckout("v3/adapty/checkout",
      type: "POST", params: [ApiParam.accountId]),

  // V2 api (to be migrated away)
  getAccountV2("v2/account", params: [ApiParam.accountId]),
  postAccountV2("v2/account", type: "POST"),
  getDeviceV2("v2/device", params: [ApiParam.accountId]),
  putDeviceV2("v2/device", type: "PUT", params: [ApiParam.accountId]),
  getListsV2("v2/list", params: [ApiParam.accountId]),
  getJournalV2("v2/activity", params: [
    ApiParam.accountId,
  ]),
  getStatsV2("v2/stats", params: [
    ApiParam.accountId,
    ApiParam.statsSince,
    ApiParam.statsDownsample,
  ]),
  getToplistV2("v2/activity/toplist", params: [
    ApiParam.accountId,
    ApiParam.toplistAction,
    ApiParam.statsDeviceName,
  ]),
  getCustomListV2("v2/customlist", params: [
    ApiParam.accountId,
  ]),
  getLeaseV2("v2/lease", params: [ApiParam.accountId]),
  postLeaseV2("v2/lease", type: "POST", params: [ApiParam.accountId]),
  deleteLeaseV2("v2/lease", type: "DELETE", params: [ApiParam.accountId]),
  postCustomListV2("v2/customlist", type: "POST", params: [ApiParam.accountId]),
  deleteCustomListV2("v2/customlist",
      type: "DELETE", params: [ApiParam.accountId]),
  postNotificationToken("v2/apple/device",
      type: "POST", params: [ApiParam.accountId]),
  postCheckoutGplayV2("v2/gplay/checkout",
      type: "POST", params: [ApiParam.accountId]),
  postCheckoutAppleV2("v2/apple/checkout",
      type: "POST", params: [ApiParam.accountId]),
  ;

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
  userAgent("user_agent"),
  accountId("account_id"),
  deviceTag("device_tag"),
  profileId("profile_id"),
  statsSince("since"),
  statsDownsample("downsample"),
  toplistAction("action"),
  statsDeviceName("device_name"),
  sessionId("session_id");

  const ApiParam(this.name) : placeholder = "($name)";

  final String name;
  final String placeholder;
}
