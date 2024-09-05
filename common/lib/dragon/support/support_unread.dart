import 'package:common/dragon/persistence/persistence.dart';
import 'package:common/dragon/value.dart';
import 'package:common/util/di.dart';

class SupportUnread extends AsyncValue<bool> {
  late final _persistence = dep<Persistence>();

  static const key = "support_unread";

  @override
  Future<bool> doLoad() async {
    return (await _persistence.load(key)) == "1";
  }

  @override
  doSave(bool value) async {
    await _persistence.save(key, value ? "1" : "0");
  }
}
