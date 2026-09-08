import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';

/// Message input for the support chat.
///
/// Exists to override two flutter_chat_ui defaults that left the chat unusable
/// on phones (issue #152): the stock composer asks for a multiline keyboard, so
/// Android IMEs render a newline key and drop the send action entirely, leaving
/// the send button as the only way to submit.
///
/// Must be placed directly in the [Chat] stack, because [Composer] returns a
/// [Positioned].
class SupportComposer extends StatelessWidget {
  /// Owned by the caller so it can pull focus back after a send, which the
  /// send action would otherwise drop along with the keyboard.
  final FocusNode? focusNode;

  const SupportComposer({super.key, this.focusNode});

  @override
  Widget build(BuildContext context) {
    return Composer(
      focusNode: focusNode,
      // A multiline keyboard type sets TYPE_TEXT_FLAG_MULTI_LINE on Android,
      // which makes every IME show a newline key regardless of the requested
      // action. Plain text keeps the send key; the field still wraps to the
      // composer's maxLines as the message grows.
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.send,
      // Hardware keyboards do not go through the IME action: Enter sends,
      // Shift+Enter still inserts a newline.
      sendOnEnter: true,
    );
  }
}
