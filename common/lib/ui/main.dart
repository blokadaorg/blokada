import 'package:common/model/UiModel.dart';
import 'package:common/ui/frontscreen.dart';
import 'package:common/ui/radial_segment.dart';
import 'package:common/ui/selector.dart';
import 'package:expandable_bottom_bar/expandable_bottom_bar.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../repo/Repos.dart';
import 'column_chart.dart';
import 'home.dart';


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
    var bbc = DefaultBottomBarController.of(context);
    return Scaffold(
      body: Home(),
      // Set [extendBody] to true for bottom app bar overlap body content
      extendBody: true,
      // Lets use docked FAB for handling state of sheet
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: GestureDetector(
        //
        // Set onVerticalDrag event to drag handlers of controller for swipe effect
        onVerticalDragUpdate: DefaultBottomBarController.of(context).onDrag,
        onVerticalDragEnd: DefaultBottomBarController.of(context).onDragEnd,
        child: FloatingActionButton.extended(
          label: AnimatedBuilder(
            animation: DefaultBottomBarController.of(context).state,
            builder: (context, child) => Row(
              children: [
                Text(
                  DefaultBottomBarController.of(context).isOpen
                      ? "Pull"
                      : "Pull",
                ),
                const SizedBox(width: 4.0),
                AnimatedBuilder(
                  animation: DefaultBottomBarController.of(context).state,
                  builder: (context, child) => Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.diagonal3Values(
                      1,
                      DefaultBottomBarController.of(context).state.value * 2 -
                          1,
                      1,
                    ),
                    child: child,
                  ),
                  child: RotatedBox(
                    quarterTurns: 1,
                    child: Icon(
                      Icons.chevron_right,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          elevation: 2,
          backgroundColor: Colors.deepOrange,
          foregroundColor: Colors.white,
          //
          //Set onPressed event to swap state of bottom bar
          onPressed: () => DefaultBottomBarController.of(context).swap(),
        ),
      ),

      bottomNavigationBar: BottomExpandableAppBar(
        // Provide the bar controller in build method or default controller as ancestor in a tree
        controller: bbc,
        expandedHeight: 700,
        horizontalMargin: 16,
        expandedBackColor: Theme.of(context).backgroundColor,
        // Your bottom sheet code here
        expandedBody: Padding(
          padding: const EdgeInsets.only(top: 32.0),
          child: FrontScreen(),
        ),
        shape: AutomaticNotchedShape(
            RoundedRectangleBorder(), StadiumBorder(side: BorderSide())),
      ),
    );
  }
}