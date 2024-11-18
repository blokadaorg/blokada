import 'dart:convert';

import 'package:common/common/model/model.dart';
import 'package:common/core/core.dart';

class ChatHistory extends NullableValue<SupportMessages?> {
  late final _persistence = DI.get<Persistence>();

  static const key = "support_chat_history";

  @override
  Future<SupportMessages?> doLoad() async {
    final json = await _persistence.load(key);
    if (json == null) return null;
    return SupportMessages.fromJson(jsonDecode(json));
  }

  @override
  doSave(SupportMessages? value) async {
    if (value == null) {
      await _persistence.delete(key);
      return;
    }
    await _persistence.save(key, jsonEncode(value.toJson()));
  }
}
