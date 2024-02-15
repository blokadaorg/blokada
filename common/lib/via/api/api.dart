import 'package:common/http/http.dart';
import 'package:vistraced/via.dart';

import '../../fsm/device/json.dart';
import '../../fsm/profile/json.dart';
import '../../http/channel.pg.dart';
import '../../util/di.dart';
import '../../fsm/api/api.dart';
import '../actions.dart';

part 'api.g.dart';

typedef JsonString = String;
typedef Json = Map<String, dynamic>;

@Module([
  ViaMatcher<JsonDevice>(ApiVia<JsonDevice>, of: ofApi),
  ViaMatcher<JsonProfile>(ApiVia<JsonProfile>, of: ofApi),
  ViaMatcher<List<JsonDevice>>(ApiViaList<JsonDevice>, of: ofApi),
  ViaMatcher<List<JsonProfile>>(ApiViaList<JsonProfile>, of: ofApi),
])
class ApiViaModule extends _$ApiViaModule {}

@Module([
  SimpleMatcher(Api<List<JsonProfile>>),
  SimpleMatcher(Api<List<JsonDevice>>),
  SimpleMatcher(Api<JsonDevice>),
  SimpleMatcher(Api<JsonProfile>),
  SimpleMatcher(Http),
  SimpleMatcher(HttpClient),
])
class ApiModule extends _$ApiModule {}

@Injected()
class ApiVia<T> extends HandleVia<T> {
  late final Api<T> _api;

  @override
  Future<T> get() {
    final endpoint = context as ApiEndpoint;
    return _api.get(endpoint);
  }

  @override
  Future<void> set(T value) {
    // TODO: implement set
    throw UnimplementedError();
  }

  @override
  Future<T> add(T value) async {
    // todo: new context - figure out endpoint
    return value;
  }
}

@Injected()
class ApiViaList<T> extends HandleVia<List<T>> {
  late final Api<List<T>> _api;

  @override
  Future<List<T>> get() {
    final endpoint = context as ApiEndpoint;
    return _api.get(endpoint);
  }

  @override
  Future<void> set(List<T> value) {
    throw UnimplementedError();
  }
}

@Injected()
class Api<T> {
  late final Http _http;
  final Type type = T;

  Future<T> get(ApiEndpoint endpoint) async {
    final json = await _http.call(HttpRequest(endpoint));
    return _jsonToType(json);
  }

  Future<void> request(ApiEndpoint endpoint, T payload) {
    final json = _typeToJson(payload);
    return _http.call(HttpRequest(endpoint, payload: json));
  }

  T _jsonToType(JsonString json) {
    if (type == String) return json as T;
    throw Exception("not implemented");
  }

  JsonString _typeToJson(T payload) {
    if (type == String) return payload as JsonString;
    throw Exception("not implemented");
  }
}

@Injected()
class Http {
  late final Act _act;
  late final HttpClient _client;
  late final AccountId _accountId;

  int _retries = 2;

  Future<String> call(HttpRequest payload) async {
    _retries = 2;
    await _prepare(payload, _params());
    return _call(payload);
  }

  Future<String> _call(HttpRequest request) async {
    try {
      return await _client.call(request);
    } catch (e) {
      if (e is HttpCodeException && !e.shouldRetry()) rethrow;
      if (_retries-- > 0) {
        await _sleep();
        return await _call(request);
      } else {
        rethrow;
      }
    }
  }

  _prepare(HttpRequest request, QueryParams params) async {
    if (request.retries < 0) throw Exception("invalid retries param");
    if (request.endpoint.type != "GET" && request.payload == null) {
      throw Exception("missing payload");
    }

    // Replace param template with actual values
    var url = _baseUrl() + request.endpoint.template;
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
    _retries = request.retries;
  }

  _params() => {
        ApiParam.accountId: _accountId.get(),
      };

  _baseUrl() => _act.isFamily()
      ? "https://family.api.blocka.net/"
      : "https://api.blocka.net/";

  _sleep() => Future.delayed(Duration(seconds: _act.isProd() ? 3 : 0));
}

@Injected()
class HttpClient {
  late final HttpOps _ops;

  Future<JsonString> call(HttpRequest payload) async {
    if (payload.endpoint.type == "GET") {
      return await _ops.doGet(payload.url);
    } else {
      throw Exception("Not implemented");
    }
  }
}

@Injected()
class AccountId {
  String get() => throw Exception("not implemented");
}
