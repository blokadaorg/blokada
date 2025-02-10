import 'package:common/common/module/api/api.dart';
import 'package:common/core/core.dart';
import 'package:common/platform/account/account.dart' as acc;

part 'actor.dart';

class AccountModule with Module {
  @override
  onCreateModule() async {
    await register(AccountActor());
  }
}
