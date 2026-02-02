import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:collection/collection.dart';
import 'package:common/src/features/api/domain/api.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:common/src/shared/i18n/locales.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/platform/account/account.dart' hide AccountId;
import 'package:common/src/platform/device/device.dart';
import 'package:common/src/features/stats/ui/top_domains.dart';
import 'package:common/src/platform/stage/stage.dart';
import 'package:common/src/platform/stats/api.dart' as platform_stats;
import 'package:common/src/platform/stats/toplist_store.dart';
import 'package:common/src/platform/stats/delta_store.dart';
import 'package:meta/meta.dart';
import 'package:mobx/mobx.dart';
import 'package:i18n_extension/i18n_extension.dart';

part 'actor.dart';
part 'api.dart';
part 'command.dart';
part 'event.dart';
part 'model.dart';
part 'weekly_report.dart';

@PlatformProvided()
mixin NotificationChannel {
  Future<void> doShow(String notificationId, String atWhen, String? body);
  Future<void> doDismissAll();
}

class NotificationsValue extends Value<List<NotificationEvent>> {
  NotificationsValue() : super(load: () => []);
}

// This is provided by the Plus module (only in v6)
// It's the device public key for the vpn
class PublicKeyProvidedValue extends AsyncValue<String> {}

class NotificationModule with Module {
  @override
  onCreateModule() async {
    await register(PublicKeyProvidedValue());
    await register(NotificationApi());
    await register(NotificationsValue());
    await register(NotificationActor());
    if (!Core.act.isFamily) {
      await register(WeeklyReportScheduleValue());
      await register(WeeklyReportLastNotifiedValue());
      await register(WeeklyReportPendingEventValue());
      await register(WeeklyReportOptOutValue());
      await register(WeeklyReportActor());
    }
    await register(NotificationCommand());
  }
}
