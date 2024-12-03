import 'package:common/core/core.dart';
import 'package:common/platform/http/channel.pg.dart';
import 'package:flutter/services.dart';

part 'endpoint.dart';
part 'error.dart';
part 'http.dart';
part 'value.dart';

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
  }) {
    return _http.call(
      HttpRequest(endpoint, payload: payload),
      m,
      params: params,
      headers: headers,
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
