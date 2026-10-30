import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:common/src/features/api/domain/api.dart';
import 'package:common/src/features/lock/domain/lock.dart';
import 'package:common/src/features/modal/domain/modal.dart';
import 'package:common/src/features/notification/domain/notification.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:common/src/features/support/ui/convert.dart';
import 'package:common/src/features/support/ui/support_sheet.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/platform/app/app.dart';
import 'package:common/src/platform/app/channel.pg.dart';
import 'package:common/src/platform/command/command.dart';
import 'package:common/src/platform/perm/perm.dart';
import 'package:common/src/platform/stage/channel.pg.dart';
import 'package:common/src/platform/stage/stage.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:i18n_extension/i18n_extension.dart';

part 'actor.dart';
part 'api.dart';
part 'json.dart';
part 'model.dart';
part 'unread_actor.dart';

class CurrentSession extends StringPersistedValue {
  CurrentSession() : super("support_session_id");
}

/// When the stored session expires, kept next to its id because the expiry
/// timer of the scheduler does not survive a cold start.
class SupportSessionExpiry extends StringPersistedValue {
  SupportSessionExpiry() : super("support_session_expires");
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
    await register(SupportSessionExpiry());
    await register(ChatHistory());
    await register(SupportUnread());
    await register(SupportApi());
    await register(SupportActor());
    await register(SupportUnreadActor());
  }
}
