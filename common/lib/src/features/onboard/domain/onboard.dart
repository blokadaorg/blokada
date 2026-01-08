import 'package:common/src/features/modal/domain/modal.dart';
import 'package:common/src/features/payment/domain/payment.dart';
import 'package:common/src/features/rate/domain/rate.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/platform/stage/channel.pg.dart';
import 'package:common/src/platform/stage/stage.dart';
import 'package:common/src/app_variants/v6/module/freemium/freemium.dart';

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
