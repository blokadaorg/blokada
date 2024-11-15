import 'package:common/common/persistence/persistence.dart';
import 'package:common/common/value.dart';
import 'package:common/util/di.dart';

class CurrentSession extends NullableValue<String?> {
  late final _persistence = dep<Persistence>();

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
