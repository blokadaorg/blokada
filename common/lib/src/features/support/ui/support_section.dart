import 'package:common/src/features/support/domain/support.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:common/src/features/support/ui/link_message.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/platform/stage/stage.dart';
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
    final bubbleColor = context.theme.isDarkTheme()
        ? context.theme.shadow.withOpacity(0.5)
        : context.theme.shadow;
    final bottomBarColor = context.theme.isDarkTheme()
        ? context.theme.shadow.withOpacity(0.3)
        : context.theme.shadow.withOpacity(0.5);

    return Padding(
      padding: EdgeInsets.only(
          left: 0, right: 0, top: getTopPadding(context), bottom: 0),
      child: Chat(
        chatController: _actor.controller,
        currentUserId: _actor.me.id,
        onMessageSend: _handleSendPressed,
        theme: ChatTheme.fromThemeData(Theme.of(context)).copyWith(
          colors: ChatColors.fromThemeData(Theme.of(context)).copyWith(
            surface: context.theme.bgColor,
            surfaceContainer: bubbleColor,
            surfaceContainerLow: bottomBarColor,
            surfaceContainerHigh: context.theme.bgColorHome1,
          ),
        ),
        // showUserAvatars: true,
        // showUserNames: true,
        // emptyState: Center(child: Text("support placeholder".i18n)),
        builders: Builders(
          chatAnimatedListBuilder: (context, itemBuilder) {
            return ChatAnimatedListReversed(itemBuilder: itemBuilder);
          },
          textMessageBuilder: (context, message, index,
              {required bool isSentByMe, groupStatus}) {
            return LinkMessage(
              message: message,
              index: index,
              onOpenLink: (it) {
                _stage.openUrl(it.url, Markers.userTap);
              },
            );
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
