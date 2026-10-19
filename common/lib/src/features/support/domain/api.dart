part of 'support.dart';

class SupportApi with Logging {
  late final _api = Core.get<Api>();
  late final _marshal = JsonSupportMarshal();

  Future<JsonSupportSession> createSession(Marker m, String language,
      {SupportEvent? event}) async {
    final result = await _api.request(ApiEndpoint.postSupport, m,
        payload: _marshal.fromCreateSession(JsonSupportPayloadCreateSession(
          language: language,
          event: event ?? SupportEvent.firstOpen,
          clientTools: SupportClientTool.values,
        )));
    log(m).i("create session response: $result");
    return _marshal.toSession(result);
  }

  Future<JsonSupportSession> getSession(Marker m, String sessionId) async {
    final result = await _api.request(ApiEndpoint.getSupport, m,
        params: {ApiParam.sessionId: sessionId});
    log(m).i("get session response: $result");
    return _marshal.toSession(result);
  }

  Future<JsonSupportResponse> sendEvent(
      Marker m, String sessionId, SupportEvent event) async {
    final result = await _api.request(ApiEndpoint.putSupport, m,
        payload: _marshal.fromMessage(JsonSupportPayloadMessage(
          sessionId: sessionId,
          event: event,
        )));
    log(m).i("send event response: $result");
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
    log(m).i("send msg response: $result");
    return _marshal.toResponse(result);
  }

  /// Uploads [appLog] for the agent's open attach_log action [actionId], and
  /// returns the agent's reply to it. The server takes one log per session.
  Future<JsonSupportResponse> uploadLog(
      Marker m, String sessionId, String actionId, String appLog) async {
    final result = await _api.request(ApiEndpoint.postSupportLog, m,
        params: {
          ApiParam.sessionId: Uri.encodeQueryComponent(sessionId),
          ApiParam.actionId: Uri.encodeQueryComponent(actionId),
        },
        payload: appLog,
        headers: {"Content-Type": "text/plain; charset=utf-8"});
    log(m).i("upload log response: $result");
    return _marshal.toResponse(result);
  }
}
