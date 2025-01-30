import 'package:common/core/core.dart';
import 'package:common/family/module/family/family.dart';
import 'package:common/platform/app/app.dart';
import 'package:common/platform/stage/channel.pg.dart';
import 'package:common/platform/stage/stage.dart';
import 'package:common/platform/stats/stats.dart';
import 'package:dartx/dartx.dart';

part 'actor.dart';
part 'json.dart';

@PlatformProvided()
mixin RateChannel {
  Future<void> doShowRateDialog();
}

class RateModule with Module {
  @override
  onCreateModule() async {
    await register(RateActor());
  }
}
