import 'package:common/src/features/support/domain/support.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:common/src/features/support/ui/link_message.dart';
import 'package:common/src/features/support/ui/support_composer.dart';
import 'package:common/src/features/support/ui/support_action_card.dart';
import 'package:common/src/features/support/ui/support_typing_bubble.dart';
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

  /// Owned here (not by the composer) so a send can hand focus straight back:
  /// submitting with the keyboard's send key drops focus by default, which in
  /// a chat would close the keyboard after every message.
  final _composerFocus = FocusNode();

  /// Owned here so a send refused while a reply is pending keeps its text,
  /// and an accepted one is cleared (the composer never clears by itself).
  final _composerText = TextEditingController();

  /// Built once per send state, so every rebuild hands flutter_chat_ui the
  /// identical widget the way its own `const Composer()` default does. A fresh
  /// instance per rebuild makes the composer re-measure itself after each
  /// frame and push a new height into the chat list — once per frame while
  /// the keyboard animates, which stutters the whole conversation.
  late final _composer = SupportComposer(
    focusNode: _composerFocus,
    textEditingController: _composerText,
  );
  late final _composerWaiting = SupportComposer(
    focusNode: _composerFocus,
    textEditingController: _composerText,
    sendDisabled: true,
  );

  @override
  void initState() {
    super.initState();
    _actor.onChange = _refresh;
    _actor.loadOrInit(Markers.support);
    _refresh();
  }

  @override
  void dispose() {
    _composerFocus.dispose();
    _composerText.dispose();
    super.dispose();
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
          composerBuilder: (context) =>
              _actor.replyPending ? _composerWaiting : _composer,
          chatAnimatedListBuilder: (context, itemBuilder) {
            return ChatAnimatedListReversed(
              itemBuilder: itemBuilder,
              // Sits right after the newest message, above the composer.
              bottomSliver: _bottomSliver(),
            );
          },
          customMessageBuilder: (context, message, index, {required bool isSentByMe, groupStatus}) {
            return SupportActionNote(
              note: SupportNote.values.byName(message.metadata!['note']),
              when: message.createdAt!,
            );
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

  /// The approval card while the agent's latest reply asks for a tool,
  /// with the typing indicator below it while a reply is pending.
  Widget? _bottomSliver() {
    final pending = _actor.replyPending;
    final action = _actor.action;
    final showCard = action != null;
    if (!pending && !showCard) return null;
    return SliverToBoxAdapter(
      child: Column(
        children: [
          if (showCard)
            SupportActionCard(
              tool: action.tool,
              busy: pending,
              onApprove: () => _actor.approveAction(Markers.userTap),
              onCancel: () => _actor.declineAction(Markers.userTap),
            ),
          if (pending) const SupportTypingBubble(),
        ],
      ),
    );
  }

  void _handleSendPressed(String message) {
    // The disabled button does not stop the keyboard's send action or Enter,
    // so a send during a pending reply is refused here, keeping its text for
    // when the reply is in. One message at a time keeps it to one bot turn.
    if (!_actor.replyPending) {
      _composerText.clear();
      _actor.sendMessage(message, Markers.support);
    }
    // Cancels the unfocus that the keyboard's send action would otherwise do,
    // which Flutter explicitly supports from this callback.
    _composerFocus.requestFocus();
  }
}
