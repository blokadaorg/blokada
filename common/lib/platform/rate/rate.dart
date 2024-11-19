import 'package:common/common/module/rate/rate.dart';
import 'package:common/core/core.dart';
import 'package:common/platform/rate/channel.pg.dart';

part 'channel.dart';

class PlatformRateModule with Module {
  @override
  onCreateModule(Act act) async {
    if (act.isProd) {
      await register<RateChannel>(PlatformRateChannel());
    } else {
      await register<RateChannel>(NoOpRateChanel());
    }
  }
}
