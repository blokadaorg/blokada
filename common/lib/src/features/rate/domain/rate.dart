import 'package:common/src/core/core.dart';
import 'package:common/src/app_variants/family/module/family/family.dart';
import 'package:common/src/app_variants/family/module/stats/stats.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/platform/app/app.dart';
import 'package:common/src/platform/stage/channel.pg.dart';
import 'package:common/src/platform/stage/stage.dart';
import 'package:common/src/platform/stats/stats.dart';
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
