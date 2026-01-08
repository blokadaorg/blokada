import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:provider/provider.dart';

/// A widget that displays a regular message with highlighted and clickable links.
/// Implemented based on FlyerChatTextMessage.
class LinkMessage extends StatelessWidget {
  final Function(LinkableElement) onOpenLink;

  /// The text message data model.
  final TextMessage message;

  /// The index of the message in the list.
  final int index;

  /// Padding around the message bubble content.
  final EdgeInsetsGeometry? padding;

  /// Border radius of the message bubble.
  final BorderRadiusGeometry? borderRadius;

  /// Font size for messages containing only emojis.
  final double? onlyEmojiFontSize;

  /// Background color for messages sent by the current user.
  final Color? sentBackgroundColor;

  /// Background color for messages received from other users.
  final Color? receivedBackgroundColor;

  /// Text style for messages sent by the current user.
  final TextStyle? sentTextStyle;

  /// Text style for messages received from other users.
  final TextStyle? receivedTextStyle;

  /// Text style for the message timestamp and status.
  final TextStyle? timeStyle;

  /// Whether to display the message timestamp.
  final bool showTime;

  /// Whether to display the message status (sent, delivered, seen) for sent messages.
  final bool showStatus;

  /// Position of the timestamp and status indicator relative to the text.
  final TimeAndStatusPosition timeAndStatusPosition;

  /// Creates a widget to display a text message.
  const LinkMessage({
    super.key,
    required this.message,
    required this.index,
    required this.onOpenLink,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    this.borderRadius,
    this.onlyEmojiFontSize = 48,
    this.sentBackgroundColor,
    this.receivedBackgroundColor,
    this.sentTextStyle,
    this.receivedTextStyle,
    this.timeStyle,
    this.showTime = true,
    this.showStatus = true,
    this.timeAndStatusPosition = TimeAndStatusPosition.end,
  });

  bool get _isOnlyEmoji => message.metadata?['isOnlyEmoji'] == true;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ChatTheme>();
    final isSentByMe = context.watch<UserID>() == message.authorId;
    final backgroundColor = _resolveBackgroundColor(isSentByMe, theme);
    final paragraphStyle = _resolveParagraphStyle(isSentByMe, theme);
    final timeStyle = _resolveTimeStyle(isSentByMe, theme);

    final timeAndStatus = showTime || (isSentByMe && showStatus)
        ? TimeAndStatus(
            time: message.createdAt,
            status: message.status,
            showTime: showTime,
            showStatus: isSentByMe && showStatus,
            textStyle: timeStyle,
          )
        : null;

    final textContent = Linkify(
      onOpen: onOpenLink,
      text: message.text,
      linkStyle: TextStyle(color: context.theme.accent),
      style: _isOnlyEmoji
          ? paragraphStyle?.copyWith(fontSize: onlyEmojiFontSize)
          : paragraphStyle,
    );

    return Container(
      padding: _isOnlyEmoji
          ? EdgeInsets.symmetric(
              horizontal: (padding?.horizontal ?? 0) / 2,
              vertical: 0,
            )
          : padding,
      decoration: _isOnlyEmoji
          ? null
          : BoxDecoration(
              color: backgroundColor,
              borderRadius: borderRadius ?? theme.shape,
            ),
      child: _buildContentBasedOnPosition(
        context: context,
        textContent: textContent,
        timeAndStatus: timeAndStatus,
        paragraphStyle: paragraphStyle,
      ),
    );
  }

  Widget _buildContentBasedOnPosition({
    required BuildContext context,
    required Widget textContent,
    TimeAndStatus? timeAndStatus,
    TextStyle? paragraphStyle,
  }) {
    if (timeAndStatus == null) {
      return textContent;
    }

    final textDirection = Directionality.of(context);

    switch (timeAndStatusPosition) {
      case TimeAndStatusPosition.start:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [textContent, timeAndStatus],
        );
      case TimeAndStatusPosition.inline:
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(child: textContent),
            const SizedBox(width: 4),
            timeAndStatus,
          ],
        );
      case TimeAndStatusPosition.end:
        return Stack(
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: paragraphStyle?.lineHeight ?? 0),
              child: textContent,
            ),
            Opacity(opacity: 0, child: timeAndStatus),
            Positioned.directional(
              textDirection: textDirection,
              end: 0,
              bottom: 0,
              child: timeAndStatus,
            ),
          ],
        );
    }
  }

  Color? _resolveBackgroundColor(bool isSentByMe, ChatTheme theme) {
    if (isSentByMe) {
      return sentBackgroundColor ?? theme.colors.primary;
    }
    return receivedBackgroundColor ?? theme.colors.surfaceContainer;
  }

  TextStyle? _resolveParagraphStyle(bool isSentByMe, ChatTheme theme) {
    if (isSentByMe) {
      return sentTextStyle ??
          theme.typography.bodyMedium.copyWith(color: theme.colors.onPrimary);
    }
    return receivedTextStyle ??
        theme.typography.bodyMedium.copyWith(color: theme.colors.onSurface);
  }

  TextStyle? _resolveTimeStyle(bool isSentByMe, ChatTheme theme) {
    if (isSentByMe) {
      return timeStyle ??
          theme.typography.labelSmall.copyWith(
            color:
                _isOnlyEmoji ? theme.colors.onSurface : theme.colors.onPrimary,
          );
    }
    return timeStyle ??
        theme.typography.labelSmall.copyWith(color: theme.colors.onSurface);
  }
}

/// Internal extension for calculating the visual line height of a TextStyle.
extension on TextStyle {
  /// Calculates the line height based on the style's `height` and `fontSize`.
  double get lineHeight => (height ?? 1) * (fontSize ?? 0);
}

/// A widget to display the message timestamp and status indicator.
class TimeAndStatus extends StatelessWidget {
  /// The time the message was created.
  final DateTime? time;

  /// The status of the message.
  final MessageStatus? status;

  /// Whether to display the timestamp.
  final bool showTime;

  /// Whether to display the status indicator.
  final bool showStatus;

  /// The text style for the time and status.
  final TextStyle? textStyle;

  /// Creates a widget for displaying time and status.
  const TimeAndStatus({
    super.key,
    required this.time,
    this.status,
    this.showTime = true,
    this.showStatus = true,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final timeFormat = context.watch<DateFormat>();

    return Row(
      spacing: 2,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showTime && time != null)
          Text(timeFormat.format(time!.toLocal()), style: textStyle),
        if (showStatus && status != null)
          if (status == MessageStatus.sending)
            SizedBox(
              width: 6,
              height: 6,
              child: CircularProgressIndicator(
                color: textStyle?.color,
                strokeWidth: 2,
              ),
            )
          else
            Icon(getIconForStatus(status!), color: textStyle?.color, size: 12),
      ],
    );
  }
}
