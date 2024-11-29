import 'package:common/common/module/account/account.dart';
import 'package:common/common/module/filter/filter.dart';
import 'package:common/core/core.dart';
import 'package:common/platform/device/device.dart';
import 'package:common/platform/filter/channel.pg.dart' as channel;
import 'package:dartx/dartx.dart';

part 'actor.dart';
part 'channel.dart';
part 'command.dart';

class PlatformFilterModule with Module {
  @override
  onCreateModule(Act act) async {
    if (act.isProd) {
      await register<FilterChannel>(PlatformFilterChannel());
    } else {
      await register<FilterChannel>(NoOpFilterChannel());
    }

    await register(PlatformFilterActor());
    await register(FilterCommand());
  }
}
