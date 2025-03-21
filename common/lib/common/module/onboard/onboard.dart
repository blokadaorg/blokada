import 'package:common/common/module/payment/payment.dart';
import 'package:common/core/core.dart';
import 'package:common/platform/stage/channel.pg.dart';
import 'package:common/platform/stage/stage.dart';

part 'actor.dart';

class OnboardingStepValue extends StringPersistedValue {
  OnboardingStepValue() : super("onboarding:step");
}

class OnboardModule with Module {
  @override
  onCreateModule() async {
    await register(OnboardingStepValue());
    await register(OnboardActor());
  }
}
