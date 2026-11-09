import 'dart:async';

import 'package:collection/collection.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/features/journal/domain/journal.dart';
import 'package:common/src/features/notification/domain/notification.dart';
import 'package:common/src/features/payment/domain/payment.dart';
import 'package:common/src/features/stats/domain/controller.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/platform/account/api.dart';
import 'package:common/src/platform/device/device.dart';
import 'package:common/src/platform/stats/model.dart';
import 'package:common/src/platform/stats/stats.dart';
import 'package:common/src/platform/stats/toplist_store.dart';

part 'actor.dart';
part 'headline.dart';
part 'trial.dart';

/// The daily Home experiment (#460): a Home that shows something new each
/// day, for accounts in the `daily` cohort. Control accounts never reach it.
class DailyHomeModule with Module {
  @override
  onCreateModule() async {
    await register(HomeHeadlinePickValue());
    await register(DailyHomeActor());
  }
}
