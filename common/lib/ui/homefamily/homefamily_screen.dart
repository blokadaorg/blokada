import 'package:common/service/I18nService.dart';
import 'package:common/ui/homefamily/onboardtexts.dart';
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
import '../debug/debugoptions.dart';
import '../theme.dart';
import 'biglogo.dart';
import 'ctabuttons.dart';
import 'devices.dart';

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
  final _account = dep<AccountStore>();
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

  List<Widget> _getWidgetsForCurrentState() {
    final theme = Theme.of(context).extension<BlokadaTheme>()!;

    if (!locked &&
        _onboardState == OnboardState.completed &&
        _account.type.isActive()) {
      return [
        Spacer(),
        Devices(),
      ];
    } else if (!locked && _onboardState == OnboardState.completed) {
      return [
        Spacer(),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48.0),
            child: Column(
              children: [
                Text(
                  "Hi there!",
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: theme.textPrimary),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  "Activate or restore your account to continue" + "\n\n",
                  style: TextStyle(fontSize: 18, color: theme.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            )),
        SizedBox(height: 72),
      ];
    } else if (!locked) {
      return [
        Spacer(),
        GestureDetector(
          onTap: () {
            traceAs("test", (trace) async {
              final next = _onboardState == OnboardState.firstTime
                  ? OnboardState.accountDecided
                  : OnboardState.completed;
              _onboard.setOnboardState(trace, next);
            });
          },
          child: OnboardTexts(
              step: _onboardState == OnboardState.firstTime ? 0 : 1),
        ),
      ];
    } else if (locked &&
        _onboardState == OnboardState.completed &&
        _app.status.isActive()) {
      return _widgetsForLockedOnboarded();
    } else {
      return _widgetsForLockedNotOnboarded();
    }
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
                "Almost there!",
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
              SizedBox(height: 72),
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
                "App is locked",
                style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: theme.textPrimary),
                textAlign: TextAlign.center,
              ),
            ],
          )),
      SizedBox(height: 72),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<BlokadaTheme>()!;
    return Stack(
      alignment: Alignment.center,
      children: [
        BigLogo(),
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
                          CtaButtons(),
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
    );
  }

  Future<void> _showDebugDialog(BuildContext context) {
    return showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return DebugOptions();
        });
  }
}
