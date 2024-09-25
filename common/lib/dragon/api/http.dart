import 'package:common/common/model.dart';
import 'package:common/dragon/account/account_id.dart';
import 'package:common/dragon/api/user_agent.dart';
import 'package:common/dragon/base_url.dart';
import 'package:common/http/channel.pg.dart';
import 'package:common/util/di.dart';
import 'package:flutter/services.dart';

class Http {
  late final _ops = dep<HttpOps>();
  late final _baseUrl = dep<BaseUrl>();
  late final _accountId = dep<AccountId>();
  late final _userAgent = dep<UserAgent>();
  late final _retry = dep<ApiRetryDuration>();

  Future<String> call(
    HttpRequest payload, {
    QueryParams? params,
    Headers headers = const {},
  }) async {
    final h = _headers()..addAll(headers);
    final p = _params()..addAll(params ?? {});
    await _prepare(payload, p, h);
    try {
      print("Api call: ${payload.endpoint} ${payload.url}");
      print("Api call payload: ${payload.payload}");
      return _call(payload, payload.retries);
    } on HttpCodeException catch (e) {
      throw HttpCodeException(
          e.code, "Api ${payload.endpoint} failed: ${e.message}");
    } catch (e) {
      throw Exception("Api ${payload.endpoint} failed: $e");
    }
  }

  Future<String> _call(HttpRequest request, int retries) async {
    try {
      return await _doOps(request);
    } catch (e) {
      if (e is HttpCodeException && !e.shouldRetry()) rethrow;
      if (retries - 1 > 0) {
        await _sleep();
        return await _call(request, retries - 1);
      } else {
        rethrow;
      }
    }
  }

  _prepare(HttpRequest request, QueryParams params, Headers headers) async {
    if (request.retries < 0) throw Exception("invalid retries param");
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

  Future<JsonString> _doOps(HttpRequest request) async {
    try {
      return await _ops.doRequestWithHeaders(
        request.url,
        request.payload,
        request.endpoint.type,
        request.headers,
      );
    } on PlatformException catch (e) {
      final ex = _mapException(e);
      print("Http: ${request.url}; Failed: $ex");
      throw ex;
    } catch (e) {
      print("Http: ${request.url}; Failed: $e");
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

  Map<ApiParam, String> _params() => {
        ApiParam.accountId: _accountId.now,
        ApiParam.userAgent: _userAgent.now,
      };

  Map<String, String> _headers() => {
        //"Authorization": "Bearer ${_token.value}",
        "User-Agent": _userAgent.now,
      };

  _sleep() => Future.delayed(_retry.now);
}
