import 'package:common/common/module/account/account.dart';
import 'package:common/common/module/filter/filter.dart';
import 'package:common/core/core.dart';
import 'package:common/platform/device/device.dart';
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
