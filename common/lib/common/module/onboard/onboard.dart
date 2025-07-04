import 'package:common/common/module/modal/modal.dart';
import 'package:common/common/module/payment/payment.dart';
import 'package:common/common/module/rate/rate.dart';
import 'package:common/core/core.dart';
import 'package:common/platform/stage/channel.pg.dart';
import 'package:common/platform/stage/stage.dart';
import 'package:common/v6/module/freemium/freemium.dart';

part 'actor.dart';
part 'command.dart';
part 'value.dart';

class OnboardModule with Module {
  @override
  onCreateModule() async {
    await register(OnboardIntroValue());
    await register(OnboardSafariValue());
    await register(OnboardActor());
    await register(OnboardCommand());
  }
}
