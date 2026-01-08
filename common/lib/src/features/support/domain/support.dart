import 'dart:convert';

import 'package:common/src/features/api/domain/api.dart';
import 'package:common/src/features/notification/domain/notification.dart';
import 'package:common/src/features/payment/domain/payment.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:common/src/features/support/ui/convert.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/platform/command/command.dart';
import 'package:common/src/platform/stage/stage.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
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
    await register(SupportUnreadActor());
    await register(SupportCommand());

    if (Core.act.isFamily) {
      await register(PurchaseTimeoutActor());
    }
  }
}
