import 'package:common/logger/logger.dart';

import '../../util/di.dart';
import '../model.dart';
import 'http.dart';

class Api {
  late final _http = dep<Http>();

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
