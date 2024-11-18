import 'package:common/common/widget/overlay.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/common/widget/top_bar.dart';
import 'package:common/core/core.dart';
import 'package:common/dragon/navigation.dart';
import 'package:common/family/widget/home/animated_bg.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:i18n_extension/i18n_extension.dart';
import 'package:provider/provider.dart';

class BlokadaApp extends StatelessWidget {
  final Widget? content;
  late final ctrl = dep<TopBarController>();

  late final nav = NavigationPopObserver();

  BlokadaApp({Key? key, this.content}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const plusColor = Color(0xffFF9400);
    const familyColor = Color(0xffe450ba);
    // const familyColor = Color(0xFFe450cd);
    // const familyColor = Color(0xffff5889);
    const familyColor2 = Color(0xff4ae5f6);
    const familyColor3 = Color(0xff3c8cff);
    final accentColor = cfg.act.isFamily ? familyColor : plusColor;

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
              // shadow: const Color(0xffF5F7FA),
              shadow: Color(0xffe8e8e8),
              bgMiniCard: Colors.white,
              textPrimary: Colors.black,
              textSecondary: Colors.black54,
              divider: Colors.black26,
              chatTheme: DefaultChatTheme(
                backgroundColor: Color(0xFFF2F1F6),
                inputBackgroundColor: Colors.black.withAlpha(20),
                inputTextColor: Colors.black,
                inputTextCursorColor: accentColor,
                inputBorderRadius: BorderRadius.circular(10),
                primaryColor: accentColor,
                secondaryColor: Colors.white,
              ),
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
              cloud: Color(0xFF007AFF),
              shadow: Color(0xFF424242),
              bgMiniCard: Color(0xFF1F1F1F),
              textPrimary: Colors.white,
              textSecondary: Color(0xFF99989F),
              divider: Colors.white24,
              chatTheme: DarkChatTheme(
                backgroundColor: Color(0xFF000000),
                inputBackgroundColor: Colors.white.withAlpha(20),
                inputTextColor: Colors.white,
                inputTextCursorColor: accentColor,
                inputBorderRadius: BorderRadius.circular(10),
                primaryColor: accentColor,
                secondaryColor: Color(0xFF1C1C1E),
              ),
            )
          }),
      home: Builder(builder: (context) {
        final mediaQueryData = MediaQuery.of(context);
        final scale = mediaQueryData.textScaleFactor.clamp(0.8, 1.1);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaleFactor: scale),
          //child: I18n(child: content),
          child:
              I18n(child: MainScreen(content: content, ctrl: ctrl, nav: nav)),
        );
      }),
    );
  }
}

class MainScreen extends StatefulWidget {
  final Widget? content;
  final TopBarController ctrl;
  final NavigationPopObserver nav;

  const MainScreen(
      {super.key, this.content, required this.ctrl, required this.nav});

  @override
  State<StatefulWidget> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ChangeNotifierProvider(
        create: (context) => widget.ctrl,
        child: Stack(
          children: [
            const AnimatedBg(),
            Padding(
              padding: EdgeInsets.only(
                  bottom: PlatformInfo().isSmallAndroid(context) ? 44 : 0),
              child: Navigator(
                key: widget.ctrl.navigatorKey,
                observers: [widget.ctrl, widget.nav],
                onGenerateRoute: (settings) {
                  return Navigation().generateRoute(context, settings,
                      homeContent: widget.content);
                },
              ),
            ),
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: TopCommonBar(),
            ),
            const OverlaySheet(),
          ],
        ),
      ),
    );
  }
}
