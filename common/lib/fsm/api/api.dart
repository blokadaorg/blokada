import 'dart:async';

import 'package:vistraced/annotations.dart';

import '../../http/http.dart';
import '../machine.dart';

part 'api.g.dart';

typedef QueryParams = Map<ApiParam, String>;

class HttpRequest {
  final ApiEndpoint endpoint;
  final int retries;
  String? payload;
  late String url;

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
  postDevice("v3/device", type: "POST", params: [ApiParam.accountId]),
  putDevice("v3/device", type: "PUT", params: [ApiParam.accountId]),
  deleteDevice("v3/device", type: "DELETE", params: [ApiParam.accountId]);

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
  accountId("account_id");

  const ApiParam(this.name) : placeholder = "($name)";

  final String name;
  final String placeholder;
}

@context
mixin ApiContext on Context<ApiContext> {
  String? _baseUrl;
  HttpRequest? _request;
  Map<ApiParam, String>? _params;

  String? result;
  Object? error;
  int retries = 2;

  // @action
  late Action<HttpRequest, String> _actionHttp;
  late Action<void, void> _actionSleep;
}

@States(ApiContext)
mixin ApiStates {
  @initialState
  static init(ApiContext c) async {
    if (c._baseUrl != null && c._request != null && c._params != null) {
      return prepare;
    }
  }

  static onConfig(ApiContext c, String baseUrl, QueryParams params) async {
    c.guard([init]);
    c._baseUrl = baseUrl;
    c._params = params;
    return init;
  }

  static onRequest(ApiContext c, HttpRequest request) async {
    c.guard([init]);
    c._request = request;
    return init;
  }

  static prepare(ApiContext c) async {
    final request = c._request!;
    if (request.retries < 0) throw Exception("invalid retries param");
    if (request.endpoint.type != "GET" && request.payload == null) {
      throw Exception("missing payload");
    }

    // Replace param template with actual values
    var url = c._baseUrl! + request.endpoint.template;
    for (final param in request.endpoint.params) {
      final value = c._params![param];
      if (value == null) throw Exception("missing param: $param");
      url = url.replaceAll(param.placeholder, value);
    }

    // Replace param also in payload
    if (request.payload != null) {
      for (final param in request.endpoint.params) {
        final value = c._params![param];
        if (value == null) throw Exception("missing param: $param");
        request.payload = request.payload!.replaceAll(param.placeholder, value);
      }
    }

    request.url = url;
    c._request = request;
    c.retries = request.retries;
    c.result = null;

    return fetch;
  }

  static fetch(ApiContext c) async {
    c.whenFail(retry, saveContext: true);
    try {
      c.result = await c._actionHttp(c._request!);
    } catch (e) {
      c.error = e;
      rethrow;
    }
    return success;
  }

  static retry(ApiContext c) async {
    c.whenFail(failure, saveContext: true);
    final e = c.error ?? Exception("Unknown error");
    if (e is HttpCodeException && !e.shouldRetry()) throw e;
    if (c.retries-- <= 0) throw e;
    await c._actionSleep(null);
    return fetch;
  }

  // @final
  static success(ApiContext c) async {}

  @fatalState
  static failure(ApiContext c) async {}
}
