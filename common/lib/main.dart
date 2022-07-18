import 'package:common/frontscreen.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';


import 'home.dart';
import 'pie_chart_page.dart';
import 'platform_info.dart';

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
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
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
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: FrontScreen(),
      bottomNavigationBar: null,
    );
  }
}