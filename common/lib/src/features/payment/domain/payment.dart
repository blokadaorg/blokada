import 'dart:async';
import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:common/src/features/api/domain/api.dart' as api;
import 'package:common/src/core/core.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/platform/account/api.dart';
import 'package:common/src/platform/stage/channel.pg.dart';
import 'package:common/src/platform/stage/stage.dart';
import 'package:i18n_extension/i18n_extension.dart';

part 'actor.dart';
part 'adapty.dart';
part 'adapty_key.dart';
part 'attribute_converter.dart';
part 'api.dart';
part 'channel.dart';

enum OnboardingStep {
  appStarting(1),
  onboardScreenReached(2),
  freshHomeReached(3),
  ctaTapped(4),
  accountActivated(5),
  permsPrompted(6),
  permsGranted(7),
  safariPrompted(8);

  final int order;

  const OnboardingStep(this.order);
}

class CurrentOnboardingStepValue
    extends StringifiedPersistedValue<OnboardingStep> {
  CurrentOnboardingStepValue() : super("payment:current_onboarding_step");

  @override
  OnboardingStep fromStringified(String value) {
    try {
      return OnboardingStep.values.firstWhere(
        (e) => e.name == value,
      );
    } catch (e) {
      return OnboardingStep.appStarting;
    }
  }

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
