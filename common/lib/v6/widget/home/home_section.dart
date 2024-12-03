import 'package:common/common/widget/icon.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/core/core.dart';
import 'package:common/platform/app/app.dart';
import 'package:common/platform/app/channel.pg.dart';
import 'package:common/platform/stage/stage.dart';
import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart';
import 'package:relative_scale/relative_scale.dart';

import 'actions.dart';
import 'power_button.dart';

const pathHomeStats = "home/stats";

class V6HomeSection extends StatefulWidget {
  V6HomeSection({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return V6HomeSectionState();
  }
}

class V6HomeSectionState extends State<V6HomeSection>
    with TickerProviderStateMixin, Logging, Disposables {
  final _app = Core.get<AppStore>();
  final _stage = Core.get<StageStore>();

  bool showDebug = false;
  bool working = false;

  late AnimationController controller;
  late AnimationController controllerOrange;

  var counter = 0;

  @override
  void initState() {
    super.initState();

    controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 4));
    controllerOrange =
        AnimationController(vsync: this, duration: const Duration(seconds: 1));

    autorun((_) {
      final status = _app.status;
      if (status.isWorking()) {
        controller.reverse();
        controllerOrange.reverse();
      } else if (status == AppStatus.activatedPlus) {
        controllerOrange.forward();
        controller.reverse();
      } else if (status == AppStatus.activatedCloud) {
        controller.forward();
        controllerOrange.reverse();
      } else {
        controller.reverse();
        controllerOrange.reverse();
      }

      setState(() {
        working = _app.status.isWorking() || !_stage.isReady;
      });
    });
  }

  @override
  void dispose() {
    controller.dispose();
    controllerOrange.dispose();
    disposeAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<BlokadaTheme>()!;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.bgColorHome3,
            theme.bgColorHome2,
            theme.bgColorHome1,
            theme.bgColor,
            theme.bgColor,
          ],
        ),
      ),
      child: AbsorbPointer(
        absorbing: false,
        child: Stack(
          children: [
            RelativeBuilder(builder: (context, height, width, sy, sx) {
              return Column(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 60, right: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          HomeIcon(
                            icon: Icons.help_outline,
                            onTap: () {
                              _stage.setRoute(
                                  StageTab.settings.name, Markers.userTap);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    child: Image.asset(
                      "assets/images/header.png",
                      width: 200,
                      height: 28,
                      fit: BoxFit.scaleDown,
                      color: Theme.of(context).textTheme.bodyLarge!.color,
                    ),
                  ),
                  const Spacer(),
                  const Spacer(),
                  PowerButton(),
                  const Spacer(),
                  const Spacer(),
                  const HomeActions(),
                  const Spacer(),
                  SizedBox(height: sy(60)),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}
