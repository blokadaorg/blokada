import 'package:common/common/api/api.dart';
import 'package:common/common/model/model.dart';
import 'package:common/core/core.dart';
import 'package:common/platform/custom/custom.dart';
import 'package:timeago/timeago.dart' as timeago;

part 'actor.dart';
part 'api.dart';

class JournalModule with Module {
  @override
  onCreateModule(Act act) async {
    await register(JournalApi());
    await register(JournalActor());
  }
}
