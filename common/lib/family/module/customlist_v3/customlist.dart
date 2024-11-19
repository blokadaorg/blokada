import 'package:common/common/api/api.dart';
import 'package:common/common/model/model.dart';
import 'package:common/core/core.dart';

part 'actor.dart';
part 'api.dart';

class CustomlistModule with Module {
  @override
  onCreateModule(Act act) async {
    await register(CustomlistApi());
    await register(CustomlistActor());
  }
}
