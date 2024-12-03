part of 'journal.dart';

class JournalApi {
  late final _api = Core.get<Api>();
  late final _marshal = JsonJournalMarshal();

  Future<List<JsonJournalEntry>> fetch(Marker m, DeviceTag tag) async {
    final response = await _api.get(ApiEndpoint.getJournal, m, params: {
      ApiParam.deviceTag: tag,
    });
    return _marshal.toEndpoint(response).activity;
  }

  Future<List<JsonJournalEntry>> fetchForV6(Marker m) async {
    final response = await _api.get(ApiEndpoint.getJournalV2, m);
    return _marshal.toEndpoint(response).activity;
  }
}
