import 'package:common/src/core/core.dart';
import 'package:flutter/material.dart';

class DomainNameText extends StatelessWidget {
  final String domain;
  final TextStyle? style;
  final TextOverflow? overflow;
  final String? tldSuffix;

  const DomainNameText({
    Key? key,
    required this.domain,
    this.style,
    this.overflow,
    this.tldSuffix,
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
    String? primaryPart;
    String? suffixPart;

    if (tldSuffix != null && tldSuffix!.isNotEmpty) {
      final domainLower = domain.toLowerCase();
      final suffixLower = tldSuffix!.toLowerCase();

      if (domainLower == suffixLower) {
        return Text(
          domain,
          style: style,
          overflow: overflow,
          maxLines: 1,
          softWrap: false,
        );
      }
      final index = domainLower.lastIndexOf(suffixLower);

      if (index > 0 && index + suffixLower.length == domainLower.length) {
        primaryPart = domain.substring(0, index);
        suffixPart = domain.substring(index);
      }
    }

    final parts = domain.split('.');

    if (primaryPart == null || suffixPart == null) {
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

      primaryPart = parts[0];
      suffixPart = domain.substring(primaryPart.length);
    }

    final primary = primaryPart!;
    final suffix = suffixPart!;

    if (suffix.isEmpty) {
      // No dot in domain, display normally
      return Text(
        domain,
        style: style,
        overflow: overflow,
        maxLines: 1,
        softWrap: false,
      );
    }

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
                  text: primary,
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
          text: TextSpan(text: primary, style: style),
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
                text: primary,
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
