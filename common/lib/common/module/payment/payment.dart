import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:common/common/module/api/api.dart' as api;
import 'package:common/core/core.dart';
import 'package:common/family/module/family/family.dart';
import 'package:common/platform/account/account.dart';
import 'package:common/platform/account/api.dart';
import 'package:common/platform/stage/channel.pg.dart';
import 'package:common/platform/stage/stage.dart';
import 'package:i18n_extension/i18n_extension.dart';

part 'actor.dart';
part 'adapty.dart';
part 'adapty_key.dart';
part 'api.dart';
part 'channel.dart';

enum OnboardingStep {
  appStarting(1),
  freshHomeReached(2),
  ctaTapped(3),
  accountActivated(4),
  permsPrompted(5),
  permsGranted(6);

  final int order;

  const OnboardingStep(this.order);
}

class CurrentOnboardingStepValue
    extends StringifiedPersistedValue<OnboardingStep> {
  CurrentOnboardingStepValue() : super("payment:current_onboarding_step");

  @override
  OnboardingStep fromStringified(String value) =>
      OnboardingStep.values.firstWhere(
        (e) => e.name == value,
      );

  @override
  String toStringified(OnboardingStep value) => value.name;
}

class PaymentModule with Module {
  @override
  onCreateModule() async {
    await register(CurrentOnboardingStepValue());
    await register(PaymentActor());
    await register(PaymentApi());
    await register(PaymentCommand());
    await register(AdaptyApiKey());
  }
}
