import 'package:common/common/module/payment/payment.dart';
import 'package:common/common/module/rate/rate.dart';
import 'package:common/core/core.dart';
import 'package:common/platform/stage/channel.pg.dart';
import 'package:common/platform/stage/stage.dart';

part 'actor.dart';
part 'value.dart';

class OnboardModule with Module {
  @override
  onCreateModule() async {
    await register(OnboardIntroValue());
    await register(OnboardSafariValue());
    await register(OnboardActor());
  }
}
