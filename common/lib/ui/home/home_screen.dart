import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart' as mobx;
import 'package:mobx/mobx.dart';

import '../../app/app.dart';
import '../../app/channel.pg.dart';
import '../../lock/lock.dart';
import '../../stage/channel.pg.dart';
import '../../stage/stage.dart';
import '../../util/di.dart';
import '../../util/trace.dart';
import '../debug/commanddialog.dart';
import '../debug/debugoptions.dart';
import 'actions.dart';
import 'icon.dart';
import 'power_button.dart';
import '../theme.dart';

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

    autorun((_) {
      setState(() {
        // isLocked = _lock.isLocked;
        hasPin = _lock.hasPin;
      });
    });

    controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 4));
    controllerOrange =
        AnimationController(vsync: this, duration: const Duration(seconds: 1));
    mobx.autorun((_) {
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
      setState(() {});
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
      child: Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                child: Padding(
                  padding: const EdgeInsets.only(top: 60, right: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // HomeIcon(
                      //   icon: hasPin
                      //       ? Icons.lock_outline
                      //       : Icons.lock_open_outlined,
                      //   onTap: () {
                      //     traceAs("fromWidget", (trace) async {
                      //       await _stage.setRoute(
                      //           trace, StageKnownRoute.homeLock.path);
                      //     });
                      //   },
                      // ),
                      HomeIcon(
                        icon: Icons.help_outline,
                        onTap: () {
                          traceAs("fromWidget", (trace) async {
                            await _stage.showModal(trace, StageModal.help);
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Spacer(),
              GestureDetector(
                onLongPress: () {
                  traceAs("fromWidget", (trace) async {
                    await _stage.showModal(trace, StageModal.debug);
                  });
                },
                onHorizontalDragEnd: (_) {
                  _showCommandDialog(context);
                },
                child: Image.asset(
                  "assets/images/header.png",
                  width: 220,
                  height: 60,
                  fit: BoxFit.scaleDown,
                  color: Theme.of(context).textTheme.bodyText1!.color,
                ),
              ),
              const Spacer(),
              PowerButton(),
              const SizedBox(height: 50),
              const Spacer(),
              const HomeActions(),
              const SizedBox(height: 110),
            ],
          ),
        ],
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
