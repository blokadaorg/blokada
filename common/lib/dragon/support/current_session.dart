import 'package:common/core/core.dart';

class CurrentSession extends NullableValue<String?> {
  late final _persistence = DI.get<Persistence>();

  static const key = "support_session_id";

  @override
  Future<String?> doLoad() async {
    return await _persistence.load(key);
  }

  @override
  doSave(String? value) async {
    if (value == null) {
      await _persistence.delete(key);
      return;
    }
    await _persistence.save(key, value);
  }
}
