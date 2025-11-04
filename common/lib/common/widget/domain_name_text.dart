import 'package:common/core/core.dart';
import 'package:flutter/material.dart';

class DomainNameText extends StatelessWidget {
  final String domain;
  final TextStyle? style;
  final TextOverflow? overflow;

  const DomainNameText({
    Key? key,
    required this.domain,
    this.style,
    this.overflow,
  }) : super(key: key);

  String _applyMiddleEllipsis(String text, double availableWidth, TextStyle? style) {
    if (availableWidth <= 0) return '...';

    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: double.infinity);

    if (textPainter.width <= availableWidth) {
      return text;
    }

    // Text is too long, calculate appropriate max length for ellipsis
    // Use character-based estimation: measure average char width
    final avgCharWidth = textPainter.width / text.length;

    // Account for "..." insertion overhead - measure actual ellipsis width
    final ellipsisPainter = TextPainter(
      text: TextSpan(text: '...', style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();

    // Available width minus ellipsis, divided by avg char width
    final availableForChars = availableWidth - ellipsisPainter.width;
    final maxChars = availableForChars > 0 ? (availableForChars / avgCharWidth).floor() : 0;

    if (maxChars <= 3) {
      return '...';
    }

    // Apply middle ellipsis with calculated max length
    return middleEllipsis(text, maxLength: maxChars);
  }

  @override
  Widget build(BuildContext context) {
    final parts = domain.split('.');

    if (parts.length <= 1) {
      // No dot in domain, display normally
      return Text(
        domain,
        style: style,
        overflow: overflow,
        maxLines: 1,
        softWrap: false,
      );
    }

    // First part (before first dot)
    final firstPart = parts[0];
    // Rest (everything after first dot)
    final suffix = domain.substring(firstPart.length);

    if (overflow != TextOverflow.ellipsis) {
      // No ellipsis handling needed
      return Builder(
        builder: (context) {
          // Get the base color from style or default text color from theme
          final baseColor = style?.color ?? DefaultTextStyle.of(context).style.color ?? Colors.black;

          return Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: firstPart,
                  style: style,
                ),
                TextSpan(
                  text: suffix,
                  style: style?.copyWith(
                    color: baseColor.withOpacity(0.3),
                  ) ?? TextStyle(
                    color: baseColor.withOpacity(0.3),
                  ),
                ),
              ],
            ),
            overflow: overflow,
            maxLines: 1,
            softWrap: false,
          );
        },
      );
    }

    // Use LayoutBuilder to measure available space
    return LayoutBuilder(
      builder: (context, constraints) {
        // Get the base color from style or default text color from theme
        final baseColor = style?.color ?? DefaultTextStyle.of(context).style.color ?? Colors.black;

        final suffixStyle = style?.copyWith(
          color: baseColor.withOpacity(0.3),
        ) ?? TextStyle(
          color: baseColor.withOpacity(0.3),
        );

        // Measure the first part width
        final firstPartPainter = TextPainter(
          text: TextSpan(text: firstPart, style: style),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout();

        // Calculate available width for suffix
        final availableForSuffix = constraints.maxWidth - firstPartPainter.width;

        // Apply middle ellipsis to suffix if needed
        final displaySuffix = _applyMiddleEllipsis(suffix, availableForSuffix, suffixStyle);

        return Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: firstPart,
                style: style,
              ),
              TextSpan(
                text: displaySuffix,
                style: suffixStyle,
              ),
            ],
          ),
          overflow: TextOverflow.clip,
          maxLines: 1,
          softWrap: false,
        );
      },
    );
  }
}
