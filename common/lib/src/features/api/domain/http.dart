part of 'api.dart';

class Http with Logging {
  late final _channel = Core.get<HttpChannel>();
  late final _baseUrl = Core.get<BaseUrl>();
  late final _accountId = Core.get<AccountId>();
  late final _userAgent = Core.get<UserAgent>();
  late final _retry = Core.get<ApiRetryDuration>();
  late final _app = Core.get<AppStore>();
  late final _stage = Core.get<StageStore>();
  late final _device = Core.get<DeviceStore>();
  late final _vpnStatus = Core.get<CurrentVpnStatusValue>();
  late final _dnsEnabledFor = Core.get<PrivateDnsEnabledForValue>();

  Future<String> call(
    HttpRequest payload,
    Marker m, {
    QueryParams? params,
    Headers headers = const {},
    bool skipResolvingParams = false,
  }) async {
    return await log(m).trace("call", (m) async {
      final h = (await _headers())..addAll(headers);
      final p = (await _params(skipAccount: skipResolvingParams))
        ..addAll(params ?? {});

      await _prepare(payload, p, h);
      try {
        log(m).i("Api call: ${payload.endpoint}");
        log(m).log(attr: {"url": payload.url}, sensitive: true);
        log(m).log(attr: {"payload": payload.payload}, sensitive: true);
        _logNetDiag(m, "requestStart", payload,
            attr: {"trigger": Markers.toName(m)});
        return _call(payload, payload.attempts, m);
      } on HttpCodeException catch (e) {
        throw HttpCodeException(
            e.code, "Api ${payload.endpoint} failed: ${e.message}");
      } catch (e) {
        throw Exception("Api ${payload.endpoint} failed: $e");
      }
    });
  }

  Future<String> _call(HttpRequest request, int attemptsRemaining, Marker m) async {
    final attempt = request.attempts - attemptsRemaining + 1;
    try {
      return await _doOps(request, m);
    } catch (e) {
      _logNetDiag(m, "requestFail", request,
          lvl: Level.warning,
          attr: {
            "attempt": attempt,
            "attemptsRemaining": attemptsRemaining - 1,
            "error": mapError(e),
          });
      if (e is HttpCodeException && !e.shouldRetry()) rethrow;
      if (attemptsRemaining - 1 > 0) {
        await _sleep();
        return await _call(request, attemptsRemaining - 1, m);
      } else {
        rethrow;
      }
    }
  }

  _prepare(HttpRequest request, QueryParams params, Headers headers) async {
    if (request.attempts < 1) throw Exception("invalid attempts param");
    // if (request.endpoint.type != "GET" && request.payload == null) {
    //   throw Exception("missing payload");
    // }

    // Replace param template with actual values
    var url = _baseUrl.now + request.endpoint.template;
    if (request.endpoint.template.startsWith("http")) {
      url = request.endpoint.template;
    }

    for (final param in request.endpoint.params) {
      final value = params[param];
      if (value == null) throw Exception("missing param: $param");
      url = url.replaceAll(param.placeholder, value);
    }

    // Replace param also in payload
    if (request.payload != null) {
      for (final param in request.endpoint.params) {
        final value = params[param];
        if (value == null) throw Exception("missing param: $param");
        request.payload = request.payload!.replaceAll(param.placeholder, value);
      }
    }

    request.url = url;
    request.headers = headers;
  }

  Future<JsonString> _doOps(HttpRequest request, Marker m) async {
    try {
      return await _channel.doRequestWithHeaders(
        request.url,
        request.payload,
        request.endpoint.type,
        request.headers,
      );
    } on PlatformException catch (e, s) {
      final ex = _mapException(e);
      log(m).e(msg: "doOps: failed", err: ex, stack: s);
      throw ex;
    } catch (e, s) {
      log(m).e(msg: "doOps: failed", err: e, stack: s);
      rethrow;
    }
  }

  Exception _mapException(PlatformException e) {
    final msg = e.code;
    final msg2 = e.message?.replaceFirst("java.lang.Exception: ", "") ?? "";
    if (msg.startsWith("code:")) {
      final code = int.parse(msg.substring(5));
      return HttpCodeException(code, msg);
    } else if (msg2.startsWith("code:")) {
      final code = int.parse(msg2.substring(5));
      return HttpCodeException(code, msg);
    } else {
      return e;
    }
  }

  Future<Map<ApiParam, String>> _params({bool skipAccount = false}) async {
    if (skipAccount) {
      return {
        ApiParam.userAgent: await _userAgent.now(),
      };
    } else {
      return {
        ApiParam.accountId: await _accountId.now(),
        ApiParam.userAgent: await _userAgent.now(),
      };
    }
  }

  Future<Map<String, String>> _headers() async => {
        //"Authorization": "Bearer ${_token.value}",
        "User-Agent": await _userAgent.now(),
      };

  _sleep() => Future.delayed(_retry.now);

  void _logNetDiag(
    Marker m,
    String event,
    HttpRequest request, {
    Level lvl = Level.info,
    Map<String, dynamic>? attr,
  }) {
    final url = request.url;
    final uri = Uri.tryParse(url);
    final expectedTag = _device.deviceTag;
    final route = _stage.route.route;
    log(m).log(
      msg: "[NetDiag] $event",
      lvl: lvl,
      attr: {
        "endpoint": request.endpoint.name,
        "host": uri?.host ?? "(invalid)",
        "method": request.endpoint.type,
        "route": route.path,
        "routeTab": route.tab.name,
        "routePayload": route.payload,
        "appStatus": _app.status.name,
        "appStatusStrategy": _app.conditions.toString(),
        "vpnStatus": _vpnStatus.now.name,
        "deviceTag": expectedTag,
        "deviceAlias": _device.deviceAlias,
        "privateDnsEnabledFor": _dnsEnabledFor.present,
        "privateDnsMatchesDevice":
            expectedTag != null && _dnsEnabledFor.present == expectedTag,
        ...?attr,
      },
      sensitive: true,
    );
  }
}
