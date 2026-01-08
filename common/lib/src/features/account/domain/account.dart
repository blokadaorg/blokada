import 'package:common/src/features/api/domain/api.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/platform/account/account.dart' as acc;

part 'actor.dart';

class AccountModule with Module {
  @override
  onCreateModule() async {
    await register(AccountActor());
  }
}
