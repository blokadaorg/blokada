import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:common/common/module/api/api.dart';
import 'package:common/core/core.dart';
import 'package:common/platform/account/account.dart';
import 'package:common/platform/stage/stage.dart';
import 'package:common/plus/module/keypair/keypair.dart';

part 'actor.dart';
part 'api.dart';
part 'command.dart';
part 'model.dart';

@PlatformProvided()
mixin NotificationChannel {
  Future<void> doShow(String notificationId, String atWhen, String? body);
  Future<void> doDismissAll();
}

class NotificationsValue extends Value<List<NotificationEvent>> {
  NotificationsValue() : super(load: () => []);
}

class NotificationModule with Module {
  @override
  onCreateModule() async {
    await register(NotificationApi());
    await register(NotificationsValue());
    await register(NotificationActor());
    await register(NotificationCommand());
  }
}
