import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:provider/provider.dart';

/// Bot-side bubble with animated dots, shown at the end of the support chat
/// while a reply is on its way.
///
/// Replies take seconds; without this the chat looks stuck and people send
/// their message again. It mirrors a received message bubble (same colors,
/// shape and outer padding as flutter_chat_ui's message rows), so it reads as
/// the bot typing in both light and dark themes.
class SupportTypingBubble extends StatelessWidget {
  const SupportTypingBubble({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ChatTheme>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: theme.colors.surfaceContainer,
            borderRadius: theme.shape,
          ),
          child: IsTypingIndicator(color: theme.colors.onSurface),
        ),
      ),
    );
  }
}
