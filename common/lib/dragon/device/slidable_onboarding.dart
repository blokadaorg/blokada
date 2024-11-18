import 'package:common/common/state/state.dart';
import 'package:common/core/core.dart';

class SlidableOnboarding extends NullableValue<bool?> {
  late final _persistence = DI.get<Persistence>();

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
