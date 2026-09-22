part of 'attach.dart';

class AttachApi {
  late final _api = Core.get<Api>();
  late final _marshal = JsonAttachMarshal();

  /// Asks the backend for a fresh hand-off token.
  ///
  /// The account ID is not passed in: the payload carries the endpoint
  /// placeholder and Http substitutes the current account, the same way the
  /// family auth endpoint does. That keeps this api free of account state.
  Future<JsonAttachLink> createLink(Marker m) async {
    final response = await _api.request(
      ApiEndpoint.postAuthLink,
      m,
      payload: _marshal.payload(),
    );
    return _marshal.toLink(response);
  }
}
