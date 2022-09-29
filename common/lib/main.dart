import 'package:common/model/UiModel.dart';
import 'package:common/ui/frontscreen.dart';
import 'package:common/ui/radial_segment.dart';
import 'package:common/ui/selector.dart';
import 'package:expandable_bottom_bar/expandable_bottom_bar.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:snapping_sheet/snapping_sheet.dart';

import 'repo/Repos.dart';
import 'ui/column_chart.dart';
import 'ui/frontscreentab.dart';
import 'ui/home.dart';


void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xffFF9400),
        backgroundColor: Colors.black,
        errorColor: const Color(0xffFF3B30),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xffFF9400), brightness: Brightness.light),
        textTheme: const TextTheme(
          //bodySmall: TextStyle(fontSize: 12.0, fontWeight: FontWeight.normal),
          headline1: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),
          headline2: TextStyle(fontSize: 18.0, fontStyle: FontStyle.normal),
          headline3: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
          headline4: TextStyle(fontSize: 14.0, fontWeight: FontWeight.normal, color: Color(0xffFF9400)),
        )
      ),
      themeMode: ThemeMode.dark,
      darkTheme: FlexThemeData.dark(
        scheme: FlexScheme.amber,
        darkIsTrueBlack: true,
      ),
      home: DefaultBottomBarController(
          child: const MyHomePage(title: 'Flutter Demo Home Page')),
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

  static const accountIdChannel = MethodChannel('account:id');

  var showBottom = false;

  final statsRepo = Repos.instance.stats;

  @override
  void initState() {
    super.initState();

    accountIdChannel.setMethodCallHandler((call) async {
      print("init state hello ${call.arguments}");
    });

    Repos.instance.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SnappingSheet(
            child: Home(),
            grabbingHeight: 48,
            // TODO: Add your grabbing widget here,
            grabbing: GrabbingWidget(),
            sheetBelow: SnappingSheetContent(
              sizeBehavior: SheetSizeStatic(size: 700),
              draggable: true,
              child: FrontScreen(key: UniqueKey(), autoRefresh: showBottom),
            ),
            snappingPositions: [
              SnappingPosition.factor(
                positionFactor: 0.1,
                snappingCurve: Curves.easeOutExpo,
                snappingDuration: Duration(seconds: 1),
                grabbingContentOffset: GrabbingContentOffset.top,
              ),
              SnappingPosition.factor(
                positionFactor: 0.95,
                snappingCurve: Curves.easeOutExpo,
                snappingDuration: Duration(seconds: 1),
                grabbingContentOffset: GrabbingContentOffset.bottom,
              )
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
    return Container(
      decoration: BoxDecoration(
        color: Color(0xff1c1c1e),
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
            color: Colors.grey[800],
            height: 2,
            margin: EdgeInsets.all(15).copyWith(top: 0, bottom: 0),
          )
        ],
      ),
    );
  }
}