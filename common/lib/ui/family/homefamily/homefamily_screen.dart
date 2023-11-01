import 'package:common/service/I18nService.dart';
import 'package:common/ui/family/homefamily/onboardtexts.dart';
import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart';
import 'package:relative_scale/relative_scale.dart';

import '../../../app/app.dart';
import '../../../app/channel.pg.dart';
import '../../../family/family.dart';
import '../../../family/model.dart';
import '../../../stage/channel.pg.dart';
import '../../../stage/stage.dart';
import '../../../util/di.dart';
import '../../../util/trace.dart';
import '../../debug/debugoptions.dart';
import '../../theme.dart';
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
  final _stage = dep<StageStore>();
  final _family = dep<FamilyStore>();

  late bool _working;
  late FamilyPhase _phase;
  late int _deviceChanges;

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

      _working = _app.status.isWorking() || !_stage.isReady;
    });

    autorun((_) {
      setState(() {
        _phase = _family.phase;
        _deviceChanges = _family.devicesChanges;
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

    // Working
    if (_working || _phase == FamilyPhase.starting) {
      return [
        const Spacer(),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48.0),
            child: Column(
              children: [
                Text(
                  "",
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: theme.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  "home status detail progress".i18n + "\n\n",
                  style: TextStyle(fontSize: 18, color: theme.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            )),
        const SizedBox(height: 72),
      ];
    }

    switch (_phase) {
      case FamilyPhase.linkedActive:
        return _widgetsForLinkedOnboarded();
      case FamilyPhase.lockedActive:
        return _widgetsForLockedOnboarded();
      case FamilyPhase.linkedNoPerms:
        return _widgetsForLockedNotOnboarded();
      case FamilyPhase.lockedNoPerms:
        return _widgetsForLockedNotOnboarded();
      case FamilyPhase.parentHasDevices:
        return [
          const Spacer(),
          const Devices(),
          CtaButtons(),
        ];
      case FamilyPhase.parentNoDevices:
        return [
          const Spacer(),
          const OnboardTexts(step: 1),
          CtaButtons(),
        ];
      case FamilyPhase.fresh:
        return [
          const Spacer(),
          const OnboardTexts(step: 0),
          CtaButtons(),
        ];
      default:
        {
          throw Exception("Unknown phase: $_phase");
        }
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
              CtaButtons(),
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
      CtaButtons(),
    ];
  }

  List<Widget> _widgetsForLinkedOnboarded() {
    final theme = Theme.of(context).extension<BlokadaTheme>()!;
    return [
      Spacer(),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48.0),
          child: Column(
            children: [
              Text(
                "App is linked",
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
          absorbing: _working,
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
                          // Leave space for navbar
                          (!_phase.isLocked())
                              ? SizedBox(height: sy(40))
                              : Container(),
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
