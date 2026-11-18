import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/features/payment/domain/payment.dart';
import 'package:common/src/features/stats/domain/controller.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/platform/stats/stats.dart';
import 'package:common/src/platform/stats/model.dart';

part 'actor.dart';
part 'trial.dart';

/// Home's trial line (#460): "Day 3 of 7 · 1,240 blocked so far" while a
/// store free trial runs.
class TrialHomeModule with Module {
  @override
  onCreateModule() async {
    await register(TrialHomeActor());
  }
}
