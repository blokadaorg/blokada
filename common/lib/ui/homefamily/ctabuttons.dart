import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart';

import '../../account/account.dart';
import '../../app/app.dart';
import '../../app/start/start.dart';
import '../../family/famdevice/famdevice.dart';
import '../../lock/lock.dart';
import '../../onboard/onboard.dart';
import '../../stage/channel.pg.dart';
import '../../stage/stage.dart';
import '../../util/di.dart';
import '../../util/trace.dart';
import '../minicard/minicard.dart';
import '../theme.dart';

class CtaButtons extends StatefulWidget {
  CtaButtons({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return CtaButtonsState();
  }
}

class CtaButtonsState extends State<CtaButtons>
    with TickerProviderStateMixin, Traceable, TraceOrigin {
  final _stage = dep<StageStore>();
  final _onboard = dep<OnboardStore>();
  final _lock = dep<LockStore>();
  final _account = dep<AccountStore>();
  final _app = dep<AppStore>();
  final _start = dep<AppStartStore>();
  final _famdevice = dep<FamilyDeviceStore>();

  late bool _locked;
  late OnboardState _onboardState;

  @override
  void initState() {
    super.initState();

    autorun((_) {
      setState(() {
        _locked = _lock.isLocked;
        _onboardState = _onboard.onboardState;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<BlokadaTheme>()!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Big CTA button shown during onboarding
        (!_locked && _onboardState != OnboardState.completed ||
                _onboardState == OnboardState.accountDecided ||
                !_app.status.isActive())
            ? Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: MiniCard(
                    onTap: _handleCtaTap(),
                    color: theme.family,
                    child: SizedBox(
                      height: 32,
                      child: Center(child: Text(_getCtaText())),
                    ),
                  ),
                ),
              )
            : Container(),
        // Small CTA icon shown only after onboarded
        (!_locked &&
                _onboardState == OnboardState.completed &&
                _app.status.isActive())
            ? Padding(
                padding: const EdgeInsets.all(8.0),
                child: MiniCard(
                    onTap: _handleCtaTap(),
                    color: theme.family,
                    child: SizedBox(
                      height: 32,
                      width: 32,
                      child: Icon(Icons.add_moderator_outlined),
                    )),
              )
            : Container(),
        // Small lock icon or QR icon shown always
        (_onboardState == OnboardState.firstTime && !_locked)
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
                      child: Icon(_locked ? Icons.lock : Icons.lock_open),
                    )),
              )
            : Container()
      ],
    );
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
        await _start.unpauseApp(trace);
      });
    };
  }

  _handleCtaTap() {
    return () {
      traceAs("tappedCta", (trace) async {
        if (_locked) {
          await _stage.showModal(trace, StageModal.perms);
        } else if (_onboardState == OnboardState.firstTime) {
          await _stage.showModal(trace, StageModal.payment);
        } else if (!_account.type.isActive()) {
          await _stage.showModal(trace, StageModal.payment);
        } else if (_onboardState == OnboardState.accountDecided) {
          await _stage.showModal(trace, StageModal.onboardingAccountDecided);
        } else {
          await _stage.showModal(trace, StageModal.accountLink);
          await _famdevice.addDevice(trace);
        }
      });
    };
  }

  String _getCtaText() {
    if (_onboardState == OnboardState.firstTime || !_account.type.isActive()) {
      return "Activate";
    } else if (_locked) {
      return "Finish setup";
    } else {
      return "Add a device";
    }
  }
}
