import 'package:common/common/api/api.dart';
import 'package:common/common/model/model.dart';
import 'package:common/common/navigation.dart';
import 'package:common/core/core.dart';
import 'package:common/platform/account/account.dart';
import 'package:common/platform/command/command.dart';
import 'package:common/platform/notification/notification.dart';
import 'package:common/platform/stage/channel.pg.dart';
import 'package:common/platform/stage/stage.dart';
import 'package:dartx/dartx.dart';
import 'package:i18n_extension/i18n_extension.dart';

part 'actor.dart';
part 'api.dart';
part 'command.dart';
part 'purchase_timeout_actor.dart';
part 'unread_actor.dart';
part 'value.dart';

class SupportModule with Module {
  @override
  onCreateModule(Act act) async {
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
