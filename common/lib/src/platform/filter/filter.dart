import 'package:common/src/features/account/domain/account.dart';
import 'package:common/src/features/filter/domain/filter.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/platform/device/device.dart';
import 'package:dartx/dartx.dart';

part 'actor.dart';
part 'command.dart';

class PlatformFilterModule with Module {
  @override
  onCreateModule() async {
    await register(PlatformFilterActor());
    await register(FilterCommand());
  }
}
