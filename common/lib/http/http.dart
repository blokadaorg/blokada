import 'dart:io';

import '../util/di.dart';
import '../util/trace.dart';
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
  Future<String> get(Trace trace, String url);

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
class PlatformHttpService with HttpService, Traceable {
  late final _ops = di<HttpOps>();

  @override
  Future<String> get(Trace trace, String url) async {
    return await traceWith(trace, "get", (trace) async {
      trace.addAttribute("url", url);
      return await _ops.doGet(url);
    });
  }

  @override
  Future<String> request(Trace trace, String url, HttpType type,
      {String? payload}) async {
    return await traceWith(trace, "postOrPut", (trace) async {
      trace.addAttribute("url", url);
      trace.addAttribute("payload", payload);
      trace.addAttribute("type", type);
      return await _ops.doRequest(url, payload, type.name);
    });
  }
}

/// RepeatingHttp
///
/// Will repeat the request if it fails with a retry-able error.
class RepeatingHttpService with HttpService {
  final HttpService _service;
  final int maxRetries;
  final Duration waitTime;

  RepeatingHttpService(this._service,
      {required this.maxRetries, required this.waitTime});

  @override
  Future<String> get(Trace trace, String url) async {
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
          sleep(waitTime * retries);
        } else {
          rethrow;
        }
      } on Exception catch (e) {
        if (retries < maxRetries) {
          retries++;
          trace.addEvent("retrying request");
          sleep(waitTime * retries);
        } else {
          rethrow;
        }
      }
    }
  }
}

Future<void> init() async {
  di.registerSingleton<HttpOps>(HttpOps());

  final http = RepeatingHttpService(PlatformHttpService(),
      maxRetries: 3, waitTime: const Duration(milliseconds: 500));
  di.registerSingleton<HttpService>(http);
}
