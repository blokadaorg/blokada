import 'package:flutter/material.dart';

extension ThemeOnWidget on BuildContext {
  BlokadaTheme get theme => Theme.of(this).extension<BlokadaTheme>()!;
}

class BlokadaTheme extends ThemeExtension<BlokadaTheme> {
  final Color bgColor;
  final Color bgColorHome1;
  final Color bgColorHome2;
  final Color bgColorHome3;
  final Color bgColorCard;
  final Color panelBackground;
  final Color cloud;
  final Color accent;
  final Color freemium;
  final Color shadow;
  final Color bgMiniCard;
  final Color textPrimary;
  final Color textSecondary;
  final Color divider;

  /// Text and icons on accent-filled buttons. The brand orange is too light
  /// for white text (2.2:1); near-black reads at 8.5:1.
  final Color onAccent;

  /// Text links. Null keeps the accent, which reads on dark backgrounds;
  /// light backgrounds need dark text, marked as a link by [linkUnderline].
  final Color? linkColor;

  /// Underline color for links, null for no underline.
  final Color? linkUnderline;

  /// Text labels for blocked and allowed counts, at 4.5:1 on their cards.
  final Color textBlocked;
  final Color textAllowed;

  const BlokadaTheme({
    required this.bgColor,
    required this.bgColorHome1,
    required this.bgColorHome2,
    required this.bgColorHome3,
    required this.bgColorCard,
    required this.panelBackground,
    required this.cloud,
    required this.accent,
    required this.freemium,
    required this.shadow,
    required this.bgMiniCard,
    required this.textPrimary,
    required this.textSecondary,
    required this.divider,
    this.onAccent = const Color(0xFF121212),
    this.linkColor,
    this.linkUnderline,
    this.textBlocked = const Color(0xFFFF3B30),
    this.textAllowed = const Color(0xFF33C75A),
  });

  bool isDarkTheme() => textPrimary == Colors.white;

  @override
  BlokadaTheme copyWith({
    Color? bgColor,
    Color? bgColorHome1,
    Color? bgColorHome2,
    Color? bgColorHome3,
    Color? bgColorCard,
    Color? panelBackground,
    Color? cloud,
    Color? plus,
    Color? family,
    Color? freemium,
    Color? shadow,
    Color? bgMiniCard,
    Color? textPrimary,
    Color? textSecondary,
    Color? divider,
    bool? isFamily,
    Color? onAccent,
    Color? linkColor,
    Color? linkUnderline,
    Color? textBlocked,
    Color? textAllowed,
  }) =>
      BlokadaTheme(
        bgColor: bgColor ?? this.bgColor,
        bgColorHome1: bgColorHome1 ?? this.bgColorHome1,
        bgColorHome2: bgColorHome2 ?? this.bgColorHome2,
        bgColorHome3: bgColorHome3 ?? this.bgColorHome3,
        bgColorCard: bgColorCard ?? this.bgColorCard,
        panelBackground: panelBackground ?? this.panelBackground,
        cloud: cloud ?? this.cloud,
        accent: family ?? this.accent,
        freemium: freemium ?? this.freemium,
        shadow: shadow ?? this.shadow,
        bgMiniCard: bgMiniCard ?? this.bgMiniCard,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        divider: divider ?? this.divider,
        onAccent: onAccent ?? this.onAccent,
        linkColor: linkColor ?? this.linkColor,
        linkUnderline: linkUnderline ?? this.linkUnderline,
        textBlocked: textBlocked ?? this.textBlocked,
        textAllowed: textAllowed ?? this.textAllowed,
      );

  @override
  BlokadaTheme lerp(ThemeExtension<BlokadaTheme>? other, double t) {
    if (other is! BlokadaTheme) {
      return this;
    }
    return BlokadaTheme(
      bgColor: Color.lerp(bgColor, other.bgColor, t)!,
      bgColorHome1: Color.lerp(bgColorHome1, other.bgColorHome1, t)!,
      bgColorHome2: Color.lerp(bgColorHome2, other.bgColorHome2, t)!,
      bgColorHome3: Color.lerp(bgColorHome3, other.bgColorHome3, t)!,
      bgColorCard: Color.lerp(bgColorCard, other.bgColorCard, t)!,
      panelBackground: Color.lerp(panelBackground, other.panelBackground, t)!,
      cloud: Color.lerp(cloud, other.cloud, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      freemium: Color.lerp(freemium, other.freemium, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      bgMiniCard: Color.lerp(bgMiniCard, other.bgMiniCard, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      linkColor: Color.lerp(linkColor, other.linkColor, t),
      linkUnderline: Color.lerp(linkUnderline, other.linkUnderline, t),
      textBlocked: Color.lerp(textBlocked, other.textBlocked, t)!,
      textAllowed: Color.lerp(textAllowed, other.textAllowed, t)!,
    );
  }
}


/// Accent-derived tint for persistently selected list rows (the open
/// detail in a two-pane layout) — distinct from the neutral gray press
/// feedback so "chosen" and "being tapped" read differently.
extension BlokadaThemeSelection on BlokadaTheme {
  Color get selection => accent.withOpacity(0.18);
}

extension BlokadaThemeLink on BlokadaTheme {
  /// Color of link text and the icons next to it.
  Color get link => linkColor ?? accent;

  /// [base] styled as a link: [link] colored, underlined where the theme
  /// asks for it.
  ///
  /// Pass `underline: false` in a bar, where the slot already marks the text
  /// as an action (a back label follows a chevron, an action sits in the
  /// trailing corner) and the rule would only repeat that.
  TextStyle linkStyle(TextStyle base, {bool underline = true}) {
    final line = underline ? linkUnderline : null;
    return base.copyWith(
      color: link,
      decoration: line == null ? null : TextDecoration.underline,
      decorationColor: line,
      decorationThickness: line == null ? null : 2,
    );
  }
}
