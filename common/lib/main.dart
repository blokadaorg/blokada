import 'package:common/model/UiModel.dart';
import 'package:common/service/I18nService.dart';
import 'package:common/service/Services.dart';
import 'package:common/ui/frontscreen.dart';
import 'package:common/ui/radial_segment.dart';
import 'package:common/ui/selector.dart';
import 'package:expandable_bottom_bar/expandable_bottom_bar.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:snapping_sheet/snapping_sheet.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:i18n_extension/i18n_widget.dart';

import 'repo/Repos.dart';
import 'ui/home.dart';


void main() async {
  await WidgetsFlutterBinding.ensureInitialized();
  await I18nService.loadTranslations();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
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

        Locale('en')
      ],
      title: 'Blokada',
      themeMode: ThemeMode.system,
      theme: FlexThemeData.light(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xffFF9400), brightness: Brightness.light),
        primary: const Color(0xffFF9400),
        error: const Color(0xffFF3B30),
        background: Colors.white,
        // textTheme: const TextTheme(
        //   //bodySmall: TextStyle(fontSize: 12.0, fontWeight: FontWeight.normal),
        //   headline1: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),
        //   headline2: TextStyle(fontSize: 18.0, fontStyle: FontStyle.normal),
        //   headline3: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
        //   headline4: TextStyle(fontSize: 14.0, fontWeight: FontWeight.normal, color: Color(0xffFF9400)),
        // ),
        extensions: <ThemeExtension<dynamic>>{
          const BrandTheme(
            bgGradientColorInactive: Color(0xffBDBDBD),
            bgGradientColorCloud: Color(0xff90c7fc),
            bgGradientColorPlus: Color(0xfffccf92),
            bgGradientColorBottom: Colors.white,
            panelBackground: const Color(0xffF5F7FA),
            cloud: Color(0xFF007AFF),
            plus: Color(0xffFF9400),
            shadow: const Color(0xffF5F7FA)
          )
        }
      ),
      darkTheme: FlexThemeData.dark(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xffFF9400), brightness: Brightness.dark),
        primary: const Color(0xffFF9400),
        error: const Color(0xffFF3B30),
        background: Colors.black,
        darkIsTrueBlack: true,
        extensions: <ThemeExtension<dynamic>>{
          const BrandTheme(
            bgGradientColorInactive: Color(0xFF5A5A5A),
            bgGradientColorCloud: Color(0xFF054079),
            bgGradientColorPlus: Color(0xFF8B5003),
            bgGradientColorBottom: Colors.black,
            panelBackground: const Color(0xff1c1c1e),
            cloud: Color(0xFF007AFF),
            plus: Color(0xffFF9400),
            shadow: Color(0xFF1C1C1E)
          )
        }
      ),
      builder: (context, child) {
        final mediaQueryData = MediaQuery.of(context);
        final scale = mediaQueryData.textScaleFactor.clamp(0.8, 1.1);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaleFactor: scale),
          child: I18n(child: DefaultBottomBarController(
              child: const MyHomePage(title: 'Blokada'))),
        );
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;


@override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  var showBottom = false;

  final statsRepo = Repos.instance.stats;

  final snappingSheetController = SnappingSheetController();

  @override
  void initState() {
    super.initState();

    Repos.instance.start();
  }

  @override
  Widget build(BuildContext context) {
    Services.instance.sheet.setSnappingSheetController(snappingSheetController);
    ScrollController frontScreenController = ScrollController();
    return Scaffold(
      body: Stack(
        children: [
          Home(),
          Align(
            alignment: Alignment.center,
            child: Container(
              constraints: BoxConstraints(maxWidth: 700),
              child: SnappingSheet(
                lockOverflowDrag: true,
                controller: snappingSheetController,
                child: Container(),
                grabbingHeight: 48,
                // TODO: Add your grabbing widget here,
                sheetBelow: SnappingSheetContent(
                  sizeBehavior: SheetSizeFill(),
                  draggable: true,
                  childScrollController: frontScreenController,
                  child: FrontScreen(key: UniqueKey(), autoRefresh: showBottom, controller: frontScreenController),
                ),
                snappingPositions: [
                  SnappingPosition.pixels(
                    positionPixels: 0,
                    snappingCurve: Curves.easeOutExpo,
                    snappingDuration: Duration(seconds: 1),
                    grabbingContentOffset: GrabbingContentOffset.top,
                  ),
                  Services.instance.sheet.getOpenPosition(context)
                ],
                onSnapCompleted: (sheetPosition, snappingPosition) {
                  setState(() {
                    if (sheetPosition.pixels > 500) {
                      showBottom = true;
                      statsRepo.setFrequentRefresh(true);
                    } else {
                      showBottom = false;
                      statsRepo.setFrequentRefresh(false);
                    }
                  });
                },
              ),
            ),
          ),
          // SnappingSheet(
          //   child: null,
          //   grabbingHeight: 75,
          //   // TODO: Add your grabbing widget here,
          //   grabbing: Text("Grabbing"),
          //   sheetBelow: SnappingSheetContent(
          //     sizeBehavior: SheetSizeFill(),
          //     draggable: true,
          //     child: Column(children: [Text("Hello"), Text("Hello"),Text("Hello"),],),
          //   ),
          // ),
        ],
      ),
    );
  }
}

class GrabbingWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<BrandTheme>()!;

    return Container(
      decoration: BoxDecoration(
        color: theme.panelBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(blurRadius: 25, color: Colors.black.withOpacity(0.3)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            margin: EdgeInsets.only(top: 20),
            width: 100,
            height: 7,
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          Container(
            color: theme.bgGradientColorInactive,
            height: 1,
            margin: EdgeInsets.all(15).copyWith(top: 0, bottom: 0),
          )
        ],
      ),
    );
  }
}

class BrandTheme extends ThemeExtension<BrandTheme> {
  const BrandTheme({
    required this.bgGradientColorInactive,
    required this.bgGradientColorCloud,
    required this.bgGradientColorPlus,
    required this.bgGradientColorBottom,
    required this.panelBackground,
    required this.cloud,
    required this.plus,
    required this.shadow
  });

  final Color bgGradientColorInactive;
  final Color bgGradientColorCloud;
  final Color bgGradientColorPlus;
  final Color bgGradientColorBottom;
  final Color panelBackground;
  final Color cloud;
  final Color plus;
  final Color shadow;

  // You must override the copyWith method.
  @override
  BrandTheme copyWith({
    Color? bgGradientColorInactive,
    Color? bgGradientColorCloud,
    Color? bgGradientColorPlus,
    Color? bgGradientColorBottom,
    Color? panelBackground,
    Color? cloud,
    Color? plus,
    Color? shadow,
  }) =>
      BrandTheme(
        bgGradientColorInactive: bgGradientColorInactive ?? this.bgGradientColorInactive,
        bgGradientColorCloud: bgGradientColorCloud ?? this.bgGradientColorCloud,
        bgGradientColorPlus: bgGradientColorPlus ?? this.bgGradientColorPlus,
        bgGradientColorBottom: bgGradientColorBottom ?? this.bgGradientColorBottom,
        panelBackground: panelBackground ?? this.panelBackground,
        cloud: cloud ?? this.cloud,
        plus: plus ?? this.plus,
        shadow: shadow ?? this.shadow,
      );

  // You must override the lerp method.
  @override
  BrandTheme lerp(ThemeExtension<BrandTheme>? other, double t) {
    if (other is! BrandTheme) {
      return this;
    }
    return BrandTheme(
      bgGradientColorInactive: Color.lerp(bgGradientColorInactive, other.bgGradientColorInactive, t)!,
      bgGradientColorCloud: Color.lerp(bgGradientColorCloud, other.bgGradientColorCloud, t)!,
      bgGradientColorPlus: Color.lerp(bgGradientColorPlus, other.bgGradientColorPlus, t)!,
      bgGradientColorBottom: Color.lerp(bgGradientColorBottom, other.bgGradientColorBottom, t)!,
      panelBackground: Color.lerp(panelBackground, other.panelBackground, t)!,
      cloud: Color.lerp(cloud, other.cloud, t)!,
      plus: Color.lerp(plus, other.plus, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}
