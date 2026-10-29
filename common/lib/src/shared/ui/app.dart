import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/shared/i18n/locales.dart';
import 'package:common/src/core/core.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/gestures.dart';
import 'package:common/src/features/toast/ui/toast_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:i18n_extension/i18n_extension.dart';

class BlokadaScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.unknown,
  };
}

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
    const plusColor = BlokadaPalette.orange;
    const familyColor = BlokadaPalette.magenta;
    // const familyColor = Color(0xFFe450cd);
    // const familyColor = Color(0xffff5889);
    final accentColor = Core.act.isFamily ? familyColor : plusColor;
    const freemiumColor = BlokadaPalette.teal;


    return MaterialApp(
      scrollBehavior: BlokadaScrollBehavior(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: supportedLocales,
      title: 'Blokada',
      themeMode: ThemeMode.system,
      theme: FlexThemeData.light(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: accentColor,
            brightness: Brightness.light,
          ),
          primary: accentColor,
          error: BlokadaPalette.red,
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
              cloud: BlokadaPalette.blue,
              accent: accentColor,
              freemium: freemiumColor,
              // shadow: const Color(0xffF5F7FA),
              shadow: Color(0xffe8e8e8),
              bgMiniCard: Colors.white,
              textPrimary: Colors.black,
              textSecondary: Colors.black54,
              divider: Colors.black26,
              linkColor: BlokadaPalette.ink,
              linkUnderline: accentColor,
              // 4.5:1 on white cards and the light page background.
              textBlocked: BlokadaPalette.redText,
              textAllowed: BlokadaPalette.greenText,
            )
          }),
      darkTheme: FlexThemeData.dark(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: accentColor,
            brightness: Brightness.dark,
          ),
          primary: accentColor,
          error: BlokadaPalette.red,
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
              cloud: BlokadaPalette.blue,
              shadow: Color(0xFF424242),
              bgMiniCard: Color(0xFF1F1F1F),
              textPrimary: Colors.white,
              textSecondary: Color(0xFF99989F),
              divider: Colors.white24,
            )
          }),
      // Above the root navigator, so toasts show over sheets and dialogs.
      builder: (context, child) => ToastHost(child: child ?? const SizedBox()),
      // Text follows the system text size unchanged; layouts adapt to it.
      home: I18n(child: content),
    );
  }
}
