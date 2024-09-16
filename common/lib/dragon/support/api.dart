import 'package:common/common/model.dart';
import 'package:common/dragon/api/api.dart';
import 'package:common/util/di.dart';

class SupportApi {
  late final _api = dep<Api>();
  late final _marshal = JsonSupportMarshal();

  Future<JsonSupportMessage> sendEvent(
      String sessionId, String language, SupportEvent event) async {
    final result = await _api.request(ApiEndpoint.postSupport,
        payload: _marshal.fromPayload(JsonSupportPayload(
          sessionId: sessionId,
          language: language,
          event: event,
        )));
    return _marshal.toMessage(result);
  }

  Future<JsonSupportMessage> sendMessage(
      String sessionId, String language, String message) async {
    final payload = _marshal.fromPayload(JsonSupportPayload(
      sessionId: sessionId,
      language: language,
      message: message,
    ));

    final result =
        await _api.request(ApiEndpoint.postSupport, payload: payload);
    print("sendmsg: $result");
    return _marshal.toMessage(result);
  }
}
