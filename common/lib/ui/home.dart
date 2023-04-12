import 'package:animate_gradient/animate_gradient.dart';
import 'package:common/service/I18nService.dart';
import 'package:common/ui/plusbutton.dart';
import 'package:common/ui/power_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart' as mobx;

import '../app/app.dart';
import '../app/channel.pg.dart';
import '../util/di.dart';
import 'homecounter.dart';
import 'myapp.dart';

class Home extends StatefulWidget {
  Home({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return HomeState();
  }
}

class HomeState extends State<Home> with TickerProviderStateMixin {
  final _app = di<AppStore>();

  late AnimationController controller;
  late AnimationController controller2;

  @override
  void initState() {
    super.initState();
    controller =
        AnimationController(vsync: this, duration: Duration(seconds: 5));
    controller2 =
        AnimationController(vsync: this, duration: Duration(seconds: 7));
    mobx.autorun((_) {
      final status = _app.status;
      if (status.isWorking()) {
        controller.reverse();
        controller2.reverse();
      } else if (status == AppStatus.activatedPlus) {
        controller2.forward();
        controller.reverse();
      } else if (status == AppStatus.activatedCloud) {
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
    final theme = Theme.of(context).extension<BrandTheme>()!;

    final primaryColorsActive = [
      theme.bgGradientColorInactive,
      theme.bgGradientColorInactive,
      theme.bgGradientColorInactive,
      theme.bgGradientColorBottom,
      theme.bgGradientColorBottom,
    ];

    final secondaryColorsActive = [
      theme.bgGradientColorCloud,
      theme.bgGradientColorCloud,
      theme.bgGradientColorCloud,
      theme.bgGradientColorBottom,
      theme.bgGradientColorBottom,
    ];

    const primaryColorsOrange = [
      Colors.transparent,
      Colors.transparent,
      Colors.transparent,
      Colors.transparent,
      Colors.transparent,
    ];

    final secondaryColorsActiveOrange = [
      theme.bgGradientColorPlus,
      theme.bgGradientColorPlus,
      theme.bgGradientColorPlus,
      theme.bgGradientColorBottom,
      theme.bgGradientColorBottom,
    ];

    return AnimateGradient(
      key: Key(theme.bgGradientColorInactive.toString()),
      primaryColors: primaryColorsActive,
      secondaryColors: secondaryColorsActive,
      controller: controller,
      child: AnimateGradient(
        key: Key(theme.bgGradientColorInactive.toString()),
        primaryColors: primaryColorsOrange,
        secondaryColors: secondaryColorsActiveOrange,
        controller: controller2,
        child: Padding(
          padding: const EdgeInsets.only(top: 0.0),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                "assets/images/header.png",
                width: 220,
                height: 60,
                fit: BoxFit.scaleDown,
                color: Theme.of(context).textTheme.bodyText1!.color,
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 48.0),
                child: Align(
                  alignment: AlignmentDirectional(0, 0),
                  child: Observer(builder: (_) {
                    final status = _app.status;
                    if (status.isWorking()) {
                      return Text("...",
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge!
                              .copyWith(
                                  color: theme.cloud,
                                  fontWeight: FontWeight.bold));
                    } else if (status.isActive()) {
                      return Text("home status active".i18n.toUpperCase(),
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge!
                              .copyWith(
                                  color: (status == AppStatus.activatedPlus)
                                      ? theme.plus
                                      : theme.cloud,
                                  fontWeight: FontWeight.bold));
                    } else if (status == AppStatus.paused) {
                      return Text("home status paused".i18n.toUpperCase(),
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge!
                              .copyWith(
                                  color: (status == AppStatus.activatedPlus)
                                      ? theme.plus
                                      : theme.cloud,
                                  fontWeight: FontWeight.bold));
                    } else {
                      return Text("home status deactivated".i18n.toUpperCase(),
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge!
                              .copyWith(fontWeight: FontWeight.bold));
                    }
                  }),
                ),
              ),
              // Expanded(
              //   child: PowerButton(),
              // ),
              PowerButton(),
              HomeCounter(),
              PlusButton(),
            ],
          ),
        ),
      ),
    );
  }
}
