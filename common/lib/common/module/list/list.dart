import 'package:common/common/api/api.dart';
import 'package:common/common/model/model.dart';
import 'package:common/core/core.dart';

part 'api.dart';

class ListModule with Module {
  @override
  onCreateModule(Act act) async {
    await register(ListApi());
  }
}
