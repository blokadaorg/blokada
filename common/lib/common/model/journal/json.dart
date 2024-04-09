import 'dart:convert';

import 'package:common/common/model.dart';
import 'package:common/journal/json.dart';

class JsonJournalMarshal {
  JsonJournalEndpoint toEndpoint(JsonString json) {
    return JsonJournalEndpoint.fromJson(jsonDecode(json));
  }
}
