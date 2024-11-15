import 'package:common/common/persistence/persistence.dart';
import 'package:common/common/value.dart';
import 'package:common/util/di.dart';

class SlidableOnboarding extends NullableValue<bool?> {
  late final _persistence = dep<Persistence>();

  static const key = "slidable_onboarding";

  @override
  Future<bool?> doLoad() async {
    return await _persistence.load(key) == "1";
  }

  @override
  doSave(bool? value) async {
    if (value == null) {
      await _persistence.delete(key);
      return;
    }
    await _persistence.save(key, value == true ? "1" : "");
  }
}
