import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';

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
  final Color shadow;
  final Color bgMiniCard;
  final Color textPrimary;
  final Color textSecondary;
  final Color divider;
  final ChatTheme chatTheme;

  const BlokadaTheme({
    required this.bgColor,
    required this.bgColorHome1,
    required this.bgColorHome2,
    required this.bgColorHome3,
    required this.bgColorCard,
    required this.panelBackground,
    required this.cloud,
    required this.accent,
    required this.shadow,
    required this.bgMiniCard,
    required this.textPrimary,
    required this.textSecondary,
    required this.divider,
    required this.chatTheme,
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
    Color? shadow,
    Color? bgMiniCard,
    Color? textPrimary,
    Color? textSecondary,
    Color? divider,
    ChatTheme? chatTheme,
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
        shadow: shadow ?? this.shadow,
        bgMiniCard: bgMiniCard ?? this.bgMiniCard,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        divider: divider ?? this.divider,
        chatTheme: chatTheme ?? this.chatTheme,
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
      shadow: Color.lerp(shadow, other.shadow, t)!,
      bgMiniCard: Color.lerp(bgMiniCard, other.bgMiniCard, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      chatTheme: other.chatTheme,
    );
  }
}
