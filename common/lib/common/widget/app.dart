import 'package:common/common/navigation.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/core/core.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:i18n_extension/i18n_extension.dart';

class BlokadaApp extends StatelessWidget {
  final Widget content;
  final bool isFamily;

  const BlokadaApp({
    Key? key,
    required this.content,
    required this.isFamily,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const plusColor = Color(0xffFF9400);
    const familyColor = Color(0xffe450ba);
    // const familyColor = Color(0xFFe450cd);
    // const familyColor = Color(0xffff5889);
    const familyColor2 = Color(0xff4ae5f6);
    const familyColor3 = Color(0xff3c8cff);
    final accentColor = Core.act.isFamily ? familyColor : plusColor;
    final freemiumColor = Color(0xFF48A9A6);

    Navigation.isTabletMode = isTabletMode(context);

    return MaterialApp(
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
        Locale('bg'),
        Locale('cs'),
        Locale('de'),
        Locale('es'),
        Locale('fi'),
        Locale('fr'),
        Locale('hi'),
        Locale('hu'),
        Locale('id'),
        Locale('it'),
        Locale('ja'),
        Locale('nl'),
        Locale('pl'),
        Locale('pt', 'BR'),
        Locale('ro'),
        Locale('ru'),
        Locale('sv'),
        Locale('tr'),
        Locale('zh'),
      ],
      title: 'Blokada',
      themeMode: ThemeMode.system,
      theme: FlexThemeData.light(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: accentColor,
            brightness: Brightness.light,
          ),
          primary: accentColor,
          error: const Color(0xffFF3B30),
          background: Colors.white,
          // textTheme: const TextTheme(
          //   //bodySmall: TextStyle(fontSize: 12.0, fontWeight: FontWeight.normal),
          //   headline1: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),
          //   headline2: TextStyle(fontSize: 18.0, fontStyle: FontStyle.normal),
          //   headline3: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
          //   headline4: TextStyle(
          //       fontSize: 14.0,
          //       fontWeight: FontWeight.normal,
          //       color: Color(0xffFF9400)),
          // ),
          extensions: <ThemeExtension<dynamic>>{
            BlokadaTheme(
              bgColor: Color(0xFFF2F1F6),
              bgColorHome1: Color(0xFFFFFFFF),
              bgColorHome2: Color(0xFFEFF1FA),
              bgColorHome3: Color(0xffBDBDBD),
              bgColorCard: Color(0xFFFFFFFF),
              panelBackground: const Color(0xffF5F7FA),
              cloud: Color(0xFF007AFF),
              accent: accentColor,
              freemium: freemiumColor,
              // shadow: const Color(0xffF5F7FA),
              shadow: Color(0xffe8e8e8),
              bgMiniCard: Colors.white,
              textPrimary: Colors.black,
              textSecondary: Colors.black54,
              divider: Colors.black26,
            )
          }),
      darkTheme: FlexThemeData.dark(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: accentColor,
            brightness: Brightness.dark,
          ),
          primary: accentColor,
          error: const Color(0xffFF3B30),
          background: Colors.black,
          darkIsTrueBlack: true,
          extensions: <ThemeExtension<dynamic>>{
            BlokadaTheme(
              bgColor: Color(0xFF000000),
              bgColorHome1: Color(0xFF000000),
              bgColorHome2: Color(0xFF000000),
              // bgColorHome2: Color(0xff262626),
              bgColorHome3: Color(0xff424242),
              bgColorCard: Color(0xFF1C1C1E),
              panelBackground: const Color(0xff1c1c1e),
              accent: accentColor,
              freemium: freemiumColor,
              cloud: Color(0xFF007AFF),
              shadow: Color(0xFF424242),
              bgMiniCard: Color(0xFF1F1F1F),
              textPrimary: Colors.white,
              textSecondary: Color(0xFF99989F),
              divider: Colors.white24,
            )
          }),
      home: Builder(builder: (context) {
        final mediaQueryData = MediaQuery.of(context);
        final scale = mediaQueryData.textScaleFactor.clamp(0.8, 1.1);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaleFactor: scale),
          //child: I18n(child: content),
          child: I18n(child: content),
        );
      }),
    );
  }
}
