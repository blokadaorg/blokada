import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:mobx/mobx.dart' as mobx;
import 'package:mobx/mobx.dart';
import 'package:relative_scale/relative_scale.dart';

import '../../app/app.dart';
import '../../app/channel.pg.dart';
import '../../lock/lock.dart';
import '../../onboard/onboard.dart';
import '../../stage/channel.pg.dart';
import '../../stage/stage.dart';
import '../../util/di.dart';
import '../../util/trace.dart';
import '../debug/commanddialog.dart';
import '../debug/debugoptions.dart';
import '../minicard/minicard.dart';
import '../theme.dart';
import 'device.dart';

class HomeFamilyScreen extends StatefulWidget {
  HomeFamilyScreen({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return HomeFamilyScreenState();
  }
}

class HomeFamilyScreenState extends State<HomeFamilyScreen>
    with TickerProviderStateMixin, Traceable, TraceOrigin {
  final _app = dep<AppStore>();
  final _stage = dep<StageStore>();
  final _lock = dep<LockStore>();
  final _onboard = dep<OnboardStore>();

  bool showDebug = false;
  bool locked = false;
  bool working = false;
  late OnboardState _onboardState;

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
        locked = _lock.isLocked;
        working = _app.status.isWorking() || !_stage.isReady;
      });
    });

    autorun((_) {
      setState(() {
        _onboardState = _onboard.onboardState;
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

  _handleCtaTap() {
    return () {
      traceAs("tappedCta", (trace) async {
        if (_onboardState == OnboardState.firstTime) {
          await _stage.showModal(trace, StageModal.payment);
        } else if (locked) {
          await _stage.showModal(trace, StageModal.perms);
        } else if (_onboardState == OnboardState.accountDecided) {
          await _stage.showModal(trace, StageModal.onboardingAccountDecided);
        } else {
          await _stage.showModal(trace, StageModal.accountLink);
        }
      });
    };
  }

  String _getCtaText() {
    if (_onboardState == OnboardState.firstTime) {
      return "Start here";
    } else if (locked) {
      return "Finish setup";
    } else {
      return "Add device";
    }
  }

  String _getDebugStateText() {
    if (locked) {
      if (_onboardState == OnboardState.firstTime) {
        return "Child mode. Please link this device first.";
      } else if (_onboardState == OnboardState.accountDecided) {
        return "Child mode. Please finish the setup.";
      } else {
        return "Child mode. All setup correctly!";
      }
    } else {
      if (_onboardState == OnboardState.firstTime) {
        return "Welcome! Please activate or restore your account.";
      } else if (_onboardState == OnboardState.accountDecided) {
        return "Great! Please add your child device.";
      } else {
        return "";
      }
    }
  }

  _handleAccountTap() {
    return () {
      traceAs("tappedAccountQr", (trace) async {
        await _stage.showModal(
            trace,
            _onboardState == OnboardState.firstTime
                ? StageModal.accountChange
                : StageModal.accountLink);
      });
    };
  }

  _handleLockTap() {
    return () {
      traceAs("tappedLock", (trace) async {
        await _stage.setRoute(trace, StageKnownRoute.homeOverlayLock.path);
      });
    };
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
        absorbing: working,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Stack(
            children: [
              RelativeBuilder(builder: (context, height, width, sy, sx) {
                return Column(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),
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
                        "assets/images/blokada_logo.png",
                        width: 200,
                        height: 128,
                        fit: BoxFit.scaleDown,
                        color: Theme.of(context).textTheme.bodyText1!.color,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 24.0, horizontal: 36),
                      child: Text(
                        _getDebugStateText(),
                        style: TextStyle(fontSize: 18),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const Spacer(),
                    !locked && _onboardState == OnboardState.completed
                        ? Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: HomeDevice(
                                  deviceName: "Karolinho",
                                  color: Colors.pink,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: HomeDevice(
                                  deviceName: "Little Johnny",
                                  color: Colors.green,
                                ),
                              )
                            ],
                          )
                        : Container(),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        (!locked ||
                                _onboardState == OnboardState.accountDecided)
                            ? Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: MiniCard(
                                    onTap: _handleCtaTap(),
                                    color: theme.plus,
                                    child: SizedBox(
                                      height: 32,
                                      child: Center(child: Text(_getCtaText())),
                                    ),
                                  ),
                                ),
                              )
                            : Container(),
                        (_onboardState == OnboardState.firstTime && !locked)
                            ? Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: MiniCard(
                                    onTap: _handleAccountTap(),
                                    child: SizedBox(
                                      height: 32,
                                      width: 32,
                                      child: Icon(Icons.qr_code),
                                    )),
                              )
                            : Container(),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: MiniCard(
                              onTap: _handleLockTap(),
                              child: SizedBox(
                                height: 32,
                                width: 32,
                                child:
                                    Icon(locked ? Icons.lock : Icons.lock_open),
                              )),
                        )
                      ],
                    ),
                    SizedBox(height: sy(60)),
                  ],
                );
              }),
            ],
          ),
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
