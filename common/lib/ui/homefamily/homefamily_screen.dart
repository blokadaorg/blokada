import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart';
import 'package:relative_scale/relative_scale.dart';

import '../../account/account.dart';
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
import '../touch.dart';
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
  final _account = dep<AccountStore>();

  bool showDebug = false;
  bool locked = false;
  bool working = false;
  late OnboardState _onboardState;

  late AnimationController controller;
  late AnimationController controllerOrange;

  late AnimationController _controller;
  late Animation<double> _bounceAnimation;
  late AnimationController _spinController;
  late Animation<double> _spinAnimation;

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

    _controller = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    );

    _bounceAnimation = Tween<double>(begin: 0, end: 15).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _controller.repeat(reverse: true);

    // For spin animation
    _spinController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _spinAnimation =
        Tween<double>(begin: 0, end: 2 * 3.14).animate(CurvedAnimation(
      parent: _spinController,
      curve: Curves.easeInOut,
    ));
  }

  void spinImage() {
    _spinController.forward().then((_) {
      _spinController.reset();
    });
  }

  @override
  void dispose() {
    _stage.removeOnValue(routeChanged, onRouteChanged);
    controller.dispose();
    controllerOrange.dispose();

    _controller.dispose();
    _spinController.dispose();
    super.dispose();
  }

  _handleCtaTap() {
    return () {
      traceAs("tappedCta", (trace) async {
        spinImage();
        if (locked) {
          await _stage.showModal(trace, StageModal.perms);
        } else if (_onboardState == OnboardState.firstTime) {
          await _stage.showModal(trace, StageModal.payment);
        } else if (!_account.type.isActive()) {
          await _stage.showModal(trace, StageModal.payment);
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
      return "Activate";
    } else if (locked) {
      return "Finish setup";
    } else {
      return "Add a device";
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

  List<Widget> _getWidgetsForCurrentState() {
    if (!locked && _onboardState == OnboardState.completed) {
      return _widgetsForUnlockedOnboarded();
    } else if (!locked) {
      return _widgetsForUnlockedNotOnboarded();
    } else if (locked && _onboardState == OnboardState.completed) {
      return _widgetsForLockedOnboarded();
    } else {
      return _widgetsForLockedNotOnboarded();
    }
  }

  List<Widget> _widgetsForUnlockedOnboarded() {
    final theme = Theme.of(context).extension<BlokadaTheme>()!;
    return [
      Spacer(),
      const Spacer(),
      Column(
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
      ),
    ];
  }

  List<Widget> _widgetsForUnlockedNotOnboarded() {
    final theme = Theme.of(context).extension<BlokadaTheme>()!;
    return [
      Spacer(),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48.0),
        child: _onboardState == OnboardState.firstTime
            ? Column(
                children: [
                  Text(
                    "First step",
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: theme.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Activate or restore your account to continue",
                    style: TextStyle(fontSize: 18, color: theme.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            : Column(
                children: [
                  Text(
                    "Second step",
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: theme.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Add your first device",
                    style: TextStyle(fontSize: 18, color: theme.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
      ),
    ];
  }

  List<Widget> _widgetsForLockedNotOnboarded() {
    final theme = Theme.of(context).extension<BlokadaTheme>()!;
    return [
      Spacer(),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48.0),
          child: Column(
            children: [
              Text(
                "One more step",
                style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: theme.textPrimary),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                "Please grant the necessary permissions",
                style: TextStyle(fontSize: 18, color: theme.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          )),
    ];
  }

  List<Widget> _widgetsForLockedOnboarded() {
    final theme = Theme.of(context).extension<BlokadaTheme>()!;
    return [
      Spacer(),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48.0),
          child: Column(
            children: [
              Text(
                "Locked",
                style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: theme.textPrimary),
                textAlign: TextAlign.center,
              ),
            ],
          )),
    ];
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
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  theme.bgColorHome1,
                  theme.bgColor,
                  theme.bgColor,
                ],
              ),
            ),
          ),
          AnimatedBuilder(
            animation:
                foundation.Listenable.merge([_controller, _spinController]),
            builder: (context, child) {
              return Positioned(
                top: _bounceAnimation.value,
                child: Padding(
                  padding:
                      const EdgeInsets.only(left: 64.0, right: 64, top: 90),
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001) // Perspective
                      ..rotateY(_spinAnimation.value),
                    child: GestureDetector(
                      onTap: () {
                        spinImage();
                      },
                      onHorizontalDragEnd: (_) {
                        _showCommandDialog(context);
                      },
                      child: Image.asset(
                        "assets/images/family-logo.png",
                        width: 256,
                        //height: 600,
                        //filterQuality: FilterQuality.high,
                        fit: BoxFit.contain,
                        //color: Colors.black.withOpacity(0.1),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          AbsorbPointer(
            absorbing: working,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Stack(
                children: [
                  RelativeBuilder(builder: (context, height, width, sy, sx) {
                    return Column(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: _getWidgetsForCurrentState() +
                          [
                            SizedBox(height: 72),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                (!locked ||
                                        _onboardState ==
                                            OnboardState.accountDecided)
                                    ? Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: MiniCard(
                                            onTap: _handleCtaTap(),
                                            color: theme.family,
                                            child: SizedBox(
                                              height: 32,
                                              child: Center(
                                                  child: Text(_getCtaText())),
                                            ),
                                          ),
                                        ),
                                      )
                                    : Container(),
                                (_onboardState == OnboardState.firstTime &&
                                        !locked)
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
                                (_onboardState != OnboardState.firstTime)
                                    ? Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: MiniCard(
                                            onTap: _handleLockTap(),
                                            child: SizedBox(
                                              height: 32,
                                              width: 32,
                                              child: Icon(locked
                                                  ? Icons.lock
                                                  : Icons.lock_open),
                                            )),
                                      )
                                    : Container()
                              ],
                            ),
                            !locked ? SizedBox(height: sy(40)) : Container(),
                            SizedBox(height: sy(30)),
                          ],
                    );
                  }),
                ],
              ),
            ),
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
