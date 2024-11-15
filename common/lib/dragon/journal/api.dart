import 'package:common/common/api/api.dart';
import 'package:common/common/model/model.dart';
import 'package:common/core/core.dart';

class JournalApi {
  late final _api = dep<Api>();
  late final _marshal = JsonJournalMarshal();

  Future<List<JsonJournalEntry>> fetch(Marker m, DeviceTag tag) async {
    final response = await _api.get(ApiEndpoint.getJournal, m, params: {
      ApiParam.deviceTag: tag,
    });
    return _marshal.toEndpoint(response).activity;
  }
}
