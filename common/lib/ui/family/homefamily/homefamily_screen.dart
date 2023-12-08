import 'package:common/service/I18nService.dart';
import 'package:flutter/cupertino.dart';
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
import '../../notfamily/home/icon.dart';
import '../../theme.dart';
import 'biglogo.dart';
import 'ctabuttons.dart';
import 'devices.dart';
import 'statustexts.dart';

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

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        const BigLogo(),
        _buildHelpButton(),
        AbsorbPointer(
          absorbing: _working,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: RelativeBuilder(builder: (context, height, width, sy, sx) {
              return Container(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Main home screen content
                    Column(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Spacer(),

                        // Devices list or the status texts
                        (_phase == FamilyPhase.parentHasDevices)
                            ? const Devices()
                            : StatusTexts(phase: _phase),
                        CtaButtons(),

                        // Leave space for navbar
                        (!_phase.isLocked())
                            ? SizedBox(height: sy(40))
                            : Container(),
                        SizedBox(height: sy(30)),
                      ],
                    ),

                    // Loading spinner on covering the content
                    _buildLoadingSpinner(context),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  _buildHelpButton() {
    return GestureDetector(
      child: Padding(
        padding: const EdgeInsets.only(top: 60, right: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            HomeIcon(
              icon: CupertinoIcons.question_circle,
              onTap: () {
                traceAs("tappedShowHelp", (trace) async {
                  await _stage.showModal(trace, StageModal.help);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  _buildLoadingSpinner(BuildContext context) {
    final theme = Theme.of(context).extension<BlokadaTheme>()!;
    if (_working || _phase == FamilyPhase.starting) {
      return Column(children: [
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
      ]);
    } else {
      return Container();
    }
  }

  Future<void> _showDebugDialog(BuildContext context) {
    return showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return DebugOptions();
        });
  }
}
