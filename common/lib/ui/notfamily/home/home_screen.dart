import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart';
import 'package:relative_scale/relative_scale.dart';

import '../../../app/app.dart';
import '../../../app/channel.pg.dart';
import '../../../common/widget/icon.dart';
import '../../../common/widget/theme.dart';
import '../../../lock/lock.dart';
import '../../../stage/channel.pg.dart';
import '../../../stage/stage.dart';
import '../../../util/di.dart';
import '../../../util/trace.dart';
import '../../debug/commanddialog.dart';
import '../../debug/debugoptions.dart';
import 'actions.dart';
import 'power_button.dart';

const pathHomeStats = "home/stats";

class HomeScreen extends StatefulWidget {
  HomeScreen({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return HomeScreenState();
  }
}

class HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, Traceable, TraceOrigin {
  final _app = dep<AppStore>();
  final _stage = dep<StageStore>();
  final _lock = dep<LockStore>();

  bool showDebug = false;
  bool hasPin = false;
  bool working = false;

  late AnimationController controller;
  late AnimationController controllerOrange;

  var counter = 0;

  Future<void> onRouteChanged(Trace parentTrace, StageRouteState route) async {
    if (!route.isForeground()) return;
    if (!route.isTab(StageTab.home)) return;

    if (!route.isBecameModal(StageModal.debug)) return;

    return await traceWith(parentTrace, "showDebug", (trace) async {
      // On purpose without await
      trace.addEvent("counter: ${counter++}");
      _showDebugDialog(context).then((_) {
        _stage.modalDismissed(trace);
      });
    });
  }

  @override
  void initState() {
    super.initState();

    _stage.addOnValue(routeChanged, onRouteChanged);

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
        hasPin = _lock.hasPin;
        working = _app.status.isWorking() || !_stage.isReady;
      });
    });
  }

  @override
  void dispose() {
    _stage.removeOnValue(routeChanged, onRouteChanged);
    controller.dispose();
    controllerOrange.dispose();
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
                              traceAs("tappedShowHelp", (trace) async {
                                await _stage.showModal(trace, StageModal.help);
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onLongPress: () {
                      traceAs("tappedShowDebug", (trace) async {
                        await _stage.showModal(trace, StageModal.debug);
                      });
                    },
                    onHorizontalDragEnd: (_) {
                      _showCommandDialog(context);
                    },
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

  Future<void> _showDebugDialog(BuildContext context) {
    return showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return DebugOptions();
        });
  }

  Future<void> _showCommandDialog(BuildContext context) {
    return showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return const CommandDialog();
        });
  }
}
