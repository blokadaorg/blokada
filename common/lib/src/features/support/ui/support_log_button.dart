import 'package:common/src/core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:provider/provider.dart';

/// Share log button, shown at the end of the support chat while the agent's
/// latest reply asks for the app log.
///
/// One tap sends the log into the conversation, so the user does not have to
/// share the file from settings and email it. It sits on the bot side, where
/// the request came from, and uses the chat's own colors in both themes.
class SupportLogButton extends StatelessWidget {
  final VoidCallback onPressed;

  const SupportLogButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ChatTheme>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: FilledButton.icon(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: theme.colors.primary,
            foregroundColor: theme.colors.onPrimary,
          ),
          icon: const Icon(Icons.description_outlined),
          label: Text("universal action share log".i18n),
        ),
      ),
    );
  }
}
