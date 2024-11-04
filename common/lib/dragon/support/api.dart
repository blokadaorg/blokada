import 'package:common/common/model.dart';
import 'package:common/dragon/api/api.dart';
import 'package:common/logger/logger.dart';
import 'package:common/util/di.dart';

class SupportApi with Logging {
  late final _api = dep<Api>();
  late final _marshal = JsonSupportMarshal();

  Future<JsonSupportSession> createSession(Marker m, String language,
      {SupportEvent? event}) async {
    final result = await _api.request(ApiEndpoint.postSupport, m,
        payload: _marshal.fromCreateSession(JsonSupportPayloadCreateSession(
          language: language,
          event: event ?? SupportEvent.firstOpen,
        )));
    log(m).i("create session: $result");
    return _marshal.toSession(result);
  }

  Future<JsonSupportSession> getSession(Marker m, String sessionId) async {
    final result = await _api.request(ApiEndpoint.getSupport, m,
        params: {ApiParam.sessionId: sessionId});
    log(m).i("get session: $result");
    return _marshal.toSession(result);
  }

  Future<JsonSupportResponse> sendEvent(
      Marker m, String sessionId, SupportEvent event) async {
    final result = await _api.request(ApiEndpoint.putSupport, m,
        payload: _marshal.fromMessage(JsonSupportPayloadMessage(
          sessionId: sessionId,
          event: event,
        )));
    log(m).i("send event: $result");
    return _marshal.toResponse(result);
  }

  Future<JsonSupportResponse> sendMessage(
      Marker m, String sessionId, String message) async {
    final payload = _marshal.fromMessage(JsonSupportPayloadMessage(
      sessionId: sessionId,
      message: message,
    ));

    final result =
        await _api.request(ApiEndpoint.putSupport, m, payload: payload);
    log(m).i("send msg: $result");
    return _marshal.toResponse(result);
  }
}
