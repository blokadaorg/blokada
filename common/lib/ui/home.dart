import 'package:animate_gradient/animate_gradient.dart';
import 'package:common/ui/plusbutton.dart';
import 'package:common/ui/power_button.dart';
import 'package:countup/countup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

import 'package:mobx/mobx.dart' as mobx;

import '../model/AppModel.dart';
import '../repo/Repos.dart';
import 'samples/pie_chart_sample1.dart';
import 'samples/pie_chart_sample2.dart';
import 'samples/pie_chart_sample3.dart';

class Home extends StatefulWidget {

  Home({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return HomeState();
  }

}

class HomeState extends State<Home> with TickerProviderStateMixin {

  final app = Repos.instance.app;
  final stats = Repos.instance.stats;

  final primaryColorsActive = const [
    Color(0xFF5A5A5A),
    Color(0xFF5A5A5A),
    Color(0xFF5A5A5A),
    Colors.black87,
    Colors.black87,
  ];

  final secondaryColorsActive = const [
    Color(0xFF054079),
    Color(0xFF054079),
    Color(0xFF054079),
    Colors.black87,
    Colors.black87,
  ];

  final primaryColorsOrange = const [
    Colors.transparent,
    Colors.transparent,
    Colors.transparent,
    Colors.transparent,
    Colors.transparent,
  ];

  final secondaryColorsActiveOrange = const [
    Color(0xFF8B5003),
    Color(0xFF8B5003),
    Color(0xFF8B5003),
    Colors.black87,
    Colors.black87,
  ];

  late AnimationController controller;
  late AnimationController controller2;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(vsync: this, duration: Duration(seconds: 5));
    controller2 = AnimationController(vsync: this, duration: Duration(seconds: 5));
    mobx.autorun((_) {
      if (app.appState.working) {
        controller.reverse();
        controller2.reverse();
      }
      else if (app.appState.state == AppState.activated && app.appState.plus) {
        controller2.forward();
        controller.reverse();
      } else if (app.appState.state == AppState.activated) {
        controller.forward();
        controller2.reverse();
      } else {
        controller.reverse();
        controller2.reverse();
      }
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
        return AnimateGradient(
          primaryColors: primaryColorsActive,
          secondaryColors: secondaryColorsActive,
          controller: controller,
          child: AnimateGradient(
            primaryColors: primaryColorsOrange,
            secondaryColors: secondaryColorsActiveOrange,
            controller: controller2,
            child: Padding(
              padding: const EdgeInsets.only(top: 100.0),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Image.asset("assets/images/header.png",
                    width: 220,
                    height: 60,
                    fit: BoxFit.scaleDown,
                  ),
                  Align(
                    alignment: AlignmentDirectional(0, 0),
                    child: Observer(
                        builder: (_) {
                          if (app.appState.working) {
                            return Text("...", style: Theme.of(context).textTheme.titleLarge!.copyWith(color: Color(0xFF007AFF), fontWeight: FontWeight.bold));
                          } else if (app.appState.state == AppState.activated) {
                            return Text("ACTIVE", style: Theme.of(context).textTheme.titleLarge!.copyWith(color: (app.appState.plus) ? Color(0xFFFF9400) : Color(0xFF007AFF), fontWeight: FontWeight.bold));
                          } else {
                            return Text("DEACTIVATED", style: Theme.of(context).textTheme.titleLarge!.copyWith(fontWeight: FontWeight.bold));
                          }
                        }
                    ),
                  ),
                  Spacer(),
                  // Expanded(
                  //   child: PowerButton(),
                  // ),
                  PowerButton(),
                  AnimatedOpacity(
                    opacity: (app.appState.plus && !app.appState.working) ? 1 : 0,
                    duration: Duration(milliseconds: 1000),
                    child: Text("+ protecting your privacy",
                        style: Theme.of(context).textTheme.titleMedium!.copyWith(color: Color(0xFFFF9400), fontWeight: FontWeight.bold)
                    ),
                  ),
                  Spacer(),
                  PlusButton(),
                  Spacer(),
                  Spacer(),
                ],
              ),
            ),
          ),
        );
  }
}
