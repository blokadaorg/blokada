import '../../common/model.dart';
import '../../util/di.dart';
import 'http.dart';

class Api {
  late final _http = dep<Http>();

  Future<JsonString> get(
    ApiEndpoint endpoint, {
    QueryParams? params,
  }) async {
    return await _http.call(HttpRequest(endpoint), params: params);
  }

  Future<String> request(
    ApiEndpoint endpoint, {
    QueryParams? params,
    JsonString? payload,
    Headers headers = const {},
  }) {
    return _http.call(
      HttpRequest(endpoint, payload: payload),
      params: params,
      headers: headers,
    );
  }
}
