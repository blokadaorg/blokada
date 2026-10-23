part of 'support.dart';

class SupportApi with Logging {
  late final _api = Core.get<Api>();
  late final _userAgent = Core.get<UserAgent>();
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
    final result = await _put(m, sessionId, event: event);
    log(m).i("send event response: $result");
    return _marshal.toResponse(result);
  }

  Future<JsonSupportResponse> sendMessage(
      Marker m, String sessionId, String message) async {
    final result = await _put(m, sessionId, message: message);
    log(m).i("send msg response: $result");
    return _marshal.toResponse(result);
  }

  Future<JsonString> _put(Marker m, String sessionId,
      {String? message, SupportEvent? event}) async {
    return await _api.request(ApiEndpoint.putSupport, m,
        payload: _marshal.fromMessage(JsonSupportPayloadMessage(
          sessionId: sessionId,
          userAgent: await _userAgent.now(),
          message: message,
          event: event,
          clientTools: SupportClientTool.values,
        )));
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

  /// Reports a DNS check for the agent's open dns_check action [actionId],
  /// and returns the agent's reply to it. The server can take 5 seconds.
  Future<JsonSupportResponse> reportDnsCheck(
    Marker m,
    String sessionId,
    String actionId,
    String language,
    Map<String, String> localState,
  ) async {
    final result = await _api.request(
      ApiEndpoint.postSupportCheck,
      m,
      payload: _marshal.fromDnsCheck(
        JsonSupportPayloadDnsCheck(
          sessionId: sessionId,
          actionId: actionId,
          language: language,
          localState: localState,
        ),
      ),
    );
    log(m).i("dns check response: $result");
    return _marshal.toResponse(result);
  }
}
