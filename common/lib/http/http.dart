import 'dart:io';

import 'package:common/json/json.dart';
import 'package:flutter/services.dart';

import '../util/async.dart';
import '../util/config.dart';
import '../util/di.dart';
import '../util/trace.dart';
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
    return code > 500;
  }
}

abstract class HttpService {
  Future<String> get(Trace trace, String url, {bool noRetry = false});

  Future<String> request(Trace trace, String url, HttpType type,
      {String? payload});
}

/// PlatformHttp
///
/// We do HTTP requests through the platform native code, since we need our
/// requests to be protected from the VPN (on iOS). Otherwise, we'd get stuck
/// with no connectivity when user account expires and VPN is on.
///
/// It also adds the User-Agent header to every request.
class PlatformHttpService with Traceable implements HttpService {
  late final _ops = dep<HttpOps>();

  @override
  Future<String> get(Trace trace, String url, {bool noRetry = false}) async {
    return await traceWith(trace, "get", (trace) async {
      trace.addAttribute("url", url, sensitive: true);
      _addEndpointAttribute(trace, url);

      try {
        return await _ops.doGet(url);
      } on PlatformException catch (e) {
        throw _mapException(e);
      }
    });
  }

  @override
  Future<String> request(Trace trace, String url, HttpType type,
      {String? payload}) async {
    return await traceWith(trace, "postOrPut", (trace) async {
      trace.addAttribute("type", type);
      trace.addAttribute("url", url, sensitive: true);
      trace.addAttribute("payload", payload, sensitive: true);
      _addEndpointAttribute(trace, url);

      try {
        return await _ops.doRequest(url, payload, type.name);
      } on PlatformException catch (e) {
        throw _mapException(e);
      }
    });
  }

  _addEndpointAttribute(Trace trace, String url) {
    if (url.startsWith(jsonUrl)) {
      final end = url.indexOf("?");
      final endpoint = url.substring(jsonUrl.length, (end == -1) ? null : end);
      trace.addAttribute("endpoint", endpoint);
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
class RepeatingHttpService implements HttpService, Dependable {
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
  Future<String> get(Trace trace, String url, {bool noRetry = false}) async {
    if (noRetry) return await _service.get(trace, url, noRetry: true);
    return await _repeat(trace, () => _service.get(trace, url));
  }

  @override
  Future<String> request(Trace trace, String url, HttpType type,
      {String? payload}) {
    return _repeat(
        trace, () => _service.request(trace, url, type, payload: payload));
  }

  Future<String> _repeat(Trace trace, Future<String> Function() action) async {
    var retries = 0;
    while (true) {
      try {
        return await action();
      } on HttpCodeException catch (e) {
        if (e.shouldRetry() && retries < maxRetries) {
          retries++;
          trace.addEvent("retrying request");
          await sleepAsync(waitTime * retries);
        } else {
          rethrow;
        }
      } on Exception catch (e) {
        if (retries < maxRetries) {
          retries++;
          trace.addEvent("retrying request");
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
  Future<String> get(Trace trace, String url, {bool noRetry = false}) {
    if (_shouldFail(url)) {
      throw Exception("Debug: request failed for testing");
    }
    return _service.get(trace, url);
  }

  @override
  Future<String> request(Trace trace, String url, HttpType type,
      {String? payload}) {
    if (_shouldFail(url)) {
      throw Exception("Debug: request failed for testing");
    }
    return _service.request(trace, url, type, payload: payload);
  }

  bool _shouldFail(String url) {
    for (var match in cfg.debugFailingRequests) {
      if (url.contains(match)) return true;
    }
    return false;
  }
}
