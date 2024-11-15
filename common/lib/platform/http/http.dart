import 'package:common/core/core.dart';
import 'package:flutter/services.dart';

import 'channel.act.dart';
import 'channel.pg.dart';

enum HttpType { post, put, delete }

class HttpCodeException implements Exception {
  final int code;
  final String message;

  HttpCodeException(this.code, this.message);

  @override
  String toString() {
    return 'HttpCodeException{code: $code, message: $message}';
  }

  bool shouldRetry() {
    return code >= 500;
  }
}

abstract class HttpService {
  Future<String> get(String url, Marker m, {bool noRetry = false});

  Future<String> request(String url, HttpType type, Marker m,
      {String? payload});
}

/// PlatformHttp
///
/// We do HTTP requests through the platform native code, since we need our
/// requests to be protected from the VPN (on iOS). Otherwise, we'd get stuck
/// with no connectivity when user account expires and VPN is on.
///
/// It also adds the User-Agent header to every request.
class PlatformHttpService with Logging implements HttpService {
  late final _ops = dep<HttpOps>();

  @override
  Future<String> get(String url, Marker m, {bool noRetry = false}) async {
    log(m).log(msg: "GET", attr: {"url": url}, sensitive: true);
    _addEndpointAttribute(url, m);

    try {
      return await _ops.doGet(url);
    } on PlatformException catch (e) {
      throw _mapException(e);
    }
  }

  @override
  Future<String> request(String url, HttpType type, Marker m,
      {String? payload}) async {
    log(m).log(msg: "request", attr: {"type": type});
    log(m).log(attr: {"url": url, "payload": payload}, sensitive: true);
    _addEndpointAttribute(url, m);

    try {
      return await _ops.doRequest(url, payload, type.name);
    } on PlatformException catch (e) {
      throw _mapException(e);
    }
  }

  _addEndpointAttribute(String url, Marker m) {
    if (url.startsWith(jsonUrl)) {
      final end = url.indexOf("?");
      final endpoint = url.substring(jsonUrl.length, (end == -1) ? null : end);
      log(m).pair("endpoint", endpoint);
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
}

/// RepeatingHttp
///
/// Will repeat the request if it fails with a retry-able error.
class RepeatingHttpService with Dependable, Logging implements HttpService {
  final HttpService _service;
  final int maxRetries;
  final Duration waitTime;

  RepeatingHttpService(
    this._service, {
    required this.maxRetries,
    required this.waitTime,
  });

  @override
  void attach(Act act) {
    depend<HttpOps>(getOps(act));
    depend<HttpService>(this);
  }

  @override
  Future<String> get(String url, Marker m, {bool noRetry = false}) async {
    if (noRetry) return await _service.get(url, m, noRetry: true);
    return await _repeat(() => _service.get(url, m), m);
  }

  @override
  Future<String> request(String url, HttpType type, Marker m,
      {String? payload}) {
    return _repeat(() => _service.request(url, type, m, payload: payload), m);
  }

  Future<String> _repeat(Future<String> Function() action, Marker m) async {
    var retries = 0;
    while (true) {
      try {
        return await action();
      } on HttpCodeException catch (e) {
        if (e.shouldRetry() && retries < maxRetries) {
          retries++;
          log(m).w("retrying request");
          await sleepAsync(waitTime * retries);
        } else {
          rethrow;
        }
      } on Exception catch (e) {
        if (retries < maxRetries) {
          retries++;
          log(m).w("retrying request");
          await sleepAsync(waitTime * retries);
        } else {
          rethrow;
        }
      }
    }
  }
}

// This service can fail specific requests for testing various scenarios
class DebugHttpService implements HttpService {
  final HttpService _service;

  DebugHttpService(this._service);

  @override
  Future<String> get(String url, Marker m, {bool noRetry = false}) {
    if (_shouldFail(url)) {
      throw Exception("Debug: request failed for testing");
    }
    return _service.get(url, m);
  }

  @override
  Future<String> request(String url, HttpType type, Marker m,
      {String? payload}) {
    if (_shouldFail(url)) {
      throw Exception("Debug: request failed for testing");
    }
    return _service.request(url, type, m, payload: payload);
  }

  bool _shouldFail(String url) {
    for (var match in cfg.debugFailingRequests) {
      if (url.contains(match)) return true;
    }
    return false;
  }
}
