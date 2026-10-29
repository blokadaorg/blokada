import 'package:flutter/material.dart';

extension ThemeOnWidget on BuildContext {
  BlokadaTheme get theme => Theme.of(this).extension<BlokadaTheme>()!;
}

/// Named colour values the [BlokadaTheme] tokens are built from.
///
/// One place for the brand and status hexes, named for what they are rather
/// than where they show, so a web dashboard can reuse the same names and
/// values. Widgets read the [BlokadaTheme] tokens, not these, so a token can
/// still differ between light and dark.
abstract final class BlokadaPalette {
  /// Blokada 6 brand colour and accent.
  static const orange = Color(0xFFFF9400);

  /// Blokada Family brand colour and accent.
  static const magenta = Color(0xFFE450BA);

  /// Freemium.
  static const teal = Color(0xFF48A9A6);

  /// Cloud and informational highlights.
  static const blue = Color(0xFF007AFF);

  /// Blocked requests and errors.
  static const red = Color(0xFFFF3B30);
  static const redLight = Color(0xFFFF7A6C);
  static const redDeep = Color(0xFFDE342A);

  /// [red] darkened to reach 4.5:1 as text on light backgrounds.
  static const redText = Color(0xFFD70015);

  /// Allowed requests.
  static const green = Color(0xFF33C75A);
  static const greenLight = Color(0xFF61D981);
  static const greenMid = Color(0xFF2FB653);
  static const greenDeep = Color(0xFF17933A);

  /// [green] darkened to reach 4.5:1 as text on light backgrounds.
  static const greenText = Color(0xFF147A50);

  /// Near-black for text on the accent and for links on light backgrounds.
  static const ink = Color(0xFF121212);

  /// Pastel markers that tell list items apart, such as blocklist providers.
  static const apricot = Color(0xFFFFCD8C);
  static const sky = Color(0xFFB1CCF4);
  static const pink = Color(0xFFFFA0EC);
  static const mint = Color(0xFFB1F4C8);
  static const coral = Color(0xFFFDB39C);
}

/// The app's type scale: one named style per text role.
///
/// Screens pick a role here instead of an inline `fontSize:`, so sizes stay
/// consistent as surfaces are redesigned. The styles set only size and
/// weight and inherit everything else (colour, font, spacing) from the
/// surrounding text style, exactly as the inline styles they replace did.
/// That is why this is not the Material `textTheme`: its styles also carry
/// letter spacing and line height, which would move existing text.
///
/// Other weights come from `copyWith` or [BlokadaTextStyle.semibold].
class BlokadaTypeScale {
  /// Screen title drawn in the content, like an iOS large title.
  final TextStyle largeTitle;

  /// Hero numbers, such as the all-time total.
  final TextStyle display;

  /// Section headers and the numbers on stat cards.
  final TextStyle title;

  /// Actions in a top bar.
  final TextStyle barAction;

  /// Rows and default reading text.
  final TextStyle body;

  /// Secondary text under or beside [body].
  final TextStyle callout;

  /// Small secondary text, such as row descriptions and group headers.
  final TextStyle footnote;

  /// The smallest text: timestamps, field labels, tags.
  final TextStyle caption;

  const BlokadaTypeScale({
    this.largeTitle = const TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
    this.display = const TextStyle(fontSize: 34, fontWeight: FontWeight.w600),
    this.title = const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
    this.barAction = const TextStyle(fontSize: 17),
    this.body = const TextStyle(fontSize: 16),
    this.callout = const TextStyle(fontSize: 14),
    this.footnote = const TextStyle(fontSize: 13),
    this.caption = const TextStyle(fontSize: 12),
  });
}

extension BlokadaTextStyle on TextStyle {
  /// The emphasis weight used across the app for labels and numbers.
  TextStyle get semibold => copyWith(fontWeight: FontWeight.w600);
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

  /// Fills for blocked and allowed counts in charts, the same in both themes.
  final Color blocked;
  final Color allowed;

  /// Light-to-deep ramps for the blocked and allowed rings of the Pulse chart.
  final List<Color> blockedGradient;
  final List<Color> allowedGradient;

  /// Colours that tell list items apart, cycled in order (blocklist providers).
  final List<Color> markers;

  /// Named text styles; see [BlokadaTypeScale]. Not called `type`: that
  /// would override [ThemeExtension.type], the key `Theme.extension` finds
  /// this theme by.
  final BlokadaTypeScale text;

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
    this.onAccent = BlokadaPalette.ink,
    this.linkColor,
    this.linkUnderline,
    this.textBlocked = BlokadaPalette.red,
    this.textAllowed = BlokadaPalette.green,
    this.blocked = BlokadaPalette.red,
    this.allowed = BlokadaPalette.green,
    this.blockedGradient = const [
      BlokadaPalette.redLight,
      BlokadaPalette.red,
      BlokadaPalette.redDeep,
    ],
    this.allowedGradient = const [
      BlokadaPalette.greenLight,
      BlokadaPalette.greenMid,
      BlokadaPalette.greenDeep,
    ],
    this.markers = const [
      BlokadaPalette.apricot,
      BlokadaPalette.sky,
      BlokadaPalette.pink,
      BlokadaPalette.mint,
      BlokadaPalette.coral,
    ],
    this.text = const BlokadaTypeScale(),
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
    Color? blocked,
    Color? allowed,
    List<Color>? blockedGradient,
    List<Color>? allowedGradient,
    List<Color>? markers,
    BlokadaTypeScale? text,
  }) => BlokadaTheme(
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
    blocked: blocked ?? this.blocked,
    allowed: allowed ?? this.allowed,
    blockedGradient: blockedGradient ?? this.blockedGradient,
    allowedGradient: allowedGradient ?? this.allowedGradient,
    markers: markers ?? this.markers,
    text: text ?? this.text,
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
      blocked: Color.lerp(blocked, other.blocked, t)!,
      allowed: Color.lerp(allowed, other.allowed, t)!,
      // Lists and the type scale don't interpolate; they switch halfway.
      blockedGradient: t < 0.5 ? blockedGradient : other.blockedGradient,
      allowedGradient: t < 0.5 ? allowedGradient : other.allowedGradient,
      markers: t < 0.5 ? markers : other.markers,
      text: t < 0.5 ? text : other.text,
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
