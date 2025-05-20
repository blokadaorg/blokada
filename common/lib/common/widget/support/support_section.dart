import 'package:common/common/module/support/support.dart';
import 'package:common/common/navigation.dart';
import 'package:common/common/widget/support/link_message.dart';
import 'package:common/core/core.dart';
import 'package:common/platform/stage/stage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';

class SupportSection extends StatefulWidget {
  const SupportSection({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => SupportSectionState();
}

class SupportSectionState extends State<SupportSection> {
  late final _stage = Core.get<StageStore>();
  late final _actor = Core.get<SupportActor>();
  late final _sessionInitDebounce =
      Debounce(const Duration(milliseconds: 1200));

  @override
  void initState() {
    super.initState();
    _actor.onChange = _refresh;
    _actor.loadOrInit(Markers.support);
    _refresh();
  }

  _refresh() {
    if (!mounted) return;
    setState(() {});
  }

  maybeStartSessionDelayed() {
    _sessionInitDebounce.run(() {
      if (!mounted) return;
      _actor.maybeStartSession(Markers.support);
    });
  }

  @override
  Widget build(BuildContext context) {
    maybeStartSessionDelayed();
    return Padding(
      padding: EdgeInsets.only(
          left: 0, right: 0, top: getTopPadding(context), bottom: 0),
      child: Chat(
        chatController: _actor.controller,
        currentUserId: _actor.me.id,
        onMessageSend: _handleSendPressed,
        theme: ChatTheme.fromThemeData(Theme.of(context)),
        // showUserAvatars: true,
        // showUserNames: true,
        // emptyState: Center(child: Text("support placeholder".i18n)),
        builders: Builders(
          chatAnimatedListBuilder: (context, itemBuilder) {
            return ChatAnimatedListReversed(itemBuilder: itemBuilder);
          },
          textMessageBuilder: (context, message, index) {
            return LinkMessage(
                message: message,
                index: index,
                onOpenLink: (it) {
                  _stage.openUrl(it.url, Markers.userTap);
                });
          },
        ),
        resolveUser: (id) async {
          if (id == _actor.me.id) {
            return _actor.me;
          } else {
            return _actor.notMe;
          }
        },
      ),
    );
  }

  void _handleSendPressed(String message) {
    _actor.sendMessage(message, Markers.support);
  }
}
