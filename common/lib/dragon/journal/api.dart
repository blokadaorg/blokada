import 'package:common/common/model.dart';
import 'package:common/common/model/journal/json.dart';
import 'package:common/dragon/api/api.dart';
import 'package:common/journal/json.dart';
import 'package:common/util/di.dart';

class JournalApi {
  late final _api = dep<Api>();
  late final _marshal = JsonJournalMarshal();

  Future<List<JsonJournalEntry>> fetch(DeviceTag tag) async {
    final response = await _api.get(ApiEndpoint.getJournal, params: {
      ApiParam.deviceTag: tag,
    });
    return _marshal.toEndpoint(response).activity;
  }
}
