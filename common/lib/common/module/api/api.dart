import 'package:common/core/core.dart';
import 'package:flutter/services.dart';

part 'endpoint.dart';
part 'error.dart';
part 'http.dart';

class AccountId extends AsyncValue<String> {
  AccountId(): super(sensitive: true);
}

class BaseUrl extends Value<String> {
  BaseUrl()
      : super(load: () {
          return Core.act.isFamily
              ? "https://family.api.blocka.net/"
              : "https://api.blocka.net/";
        });
}

class ApiRetryDuration extends Value<Duration> {
  ApiRetryDuration()
      : super(load: () {
          return Duration(seconds: Core.act.isProd ? 3 : 0);
        });
}

class UserAgent extends AsyncValue<String> {}

@PlatformProvided()
mixin HttpChannel {
  Future<String> doGet(String url);
  Future<String> doRequest(String url, String? payload, String type);
  Future<String> doRequestWithHeaders(
      String url, String? payload, String type, Map<String?, String?> h);
}

class Api {
  late final _http = Core.get<Http>();

  Future<JsonString> get(
    ApiEndpoint endpoint,
    Marker m, {
    QueryParams? params,
  }) async {
    return await _http.call(HttpRequest(endpoint), m, params: params);
  }

  Future<String> request(
    ApiEndpoint endpoint,
    Marker m, {
    QueryParams? params,
    JsonString? payload,
    Headers headers = const {},
    bool skipResolvingParams = false,
  }) {
    return _http.call(
      HttpRequest(endpoint, payload: payload),
      m,
      params: params,
      headers: headers,
      skipResolvingParams: skipResolvingParams,
    );
  }
}

class ApiModule with Module {
  @override
  onCreateModule() async {
    await register(BaseUrl());
    await register(UserAgent());
    await register(ApiRetryDuration());

    await register(AccountId());
    await register(Http());

    await register(Api());
  }
}
