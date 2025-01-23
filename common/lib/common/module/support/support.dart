import 'dart:convert';

import 'package:common/common/module/api/api.dart';
import 'package:common/common/module/notification/notification.dart';
import 'package:common/common/navigation.dart';
import 'package:common/core/core.dart';
import 'package:common/platform/account/account.dart';
import 'package:common/platform/command/command.dart';
import 'package:common/platform/stage/channel.pg.dart';
import 'package:common/platform/stage/stage.dart';
import 'package:dartx/dartx.dart';
import 'package:i18n_extension/i18n_extension.dart';

part 'actor.dart';
part 'api.dart';
part 'command.dart';
part 'json.dart';
part 'model.dart';
part 'purchase_timeout_actor.dart';
part 'unread_actor.dart';

class CurrentSession extends StringPersistedValue {
  CurrentSession() : super("support_session_id");
}

class ChatHistory extends JsonPersistedValue<SupportMessages> {
  ChatHistory() : super("support_chat_history");

  @override
  SupportMessages fromJson(Map<String, dynamic> json) =>
      SupportMessages.fromJson(json);

  @override
  Map<String, dynamic> toJson(SupportMessages value) => value.toJson();
}

class SupportUnread extends BoolPersistedValue {
  SupportUnread() : super("support_unread");
}

class SupportModule with Module {
  @override
  onCreateModule() async {
    await register(CurrentSession());
    await register(ChatHistory());
    await register(SupportUnread());
    await register(SupportApi());
    await register(SupportActor());
    await register(PurchaseTimeoutActor());
    await register(SupportUnreadActor());
    await register(SupportCommand());
  }
}
