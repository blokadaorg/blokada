import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart';

import '../../../account/account.dart';
import '../../../app/app.dart';
import '../../../family/family.dart';
import '../../../family/model.dart';
import '../../../lock/lock.dart';
import '../../../stage/channel.pg.dart';
import '../../../stage/stage.dart';
import '../../../util/di.dart';
import '../../../util/trace.dart';
import '../../minicard/minicard.dart';
import '../../theme.dart';

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
  final _family = dep<FamilyStore>();

  late FamilyPhase _phase;
  late bool _hasThisDevice;

  @override
  void initState() {
    super.initState();

    autorun((_) {
      setState(() {
        _phase = _family.phase;
        _hasThisDevice = _family.hasThisDevice;
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
        (_phase.requiresAction())
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
        (!_phase.requiresAction() && _phase.isParent() && !_phase.isLocked())
            ? Padding(
                padding: const EdgeInsets.all(8.0),
                child: MiniCard(
                    onTap: _handleCtaTap(),
                    color: theme.family,
                    child: const SizedBox(
                      height: 32,
                      width: 32,
                      child: Icon(Icons.add_circle_outline),
                    )),
              )
            : Container(),
        // Small lock icon or QR icon shown always
        (_phase == FamilyPhase.fresh || _phase == FamilyPhase.parentNoDevices)
            ? Padding(
                padding: const EdgeInsets.all(8.0),
                child: MiniCard(
                    onTap: _handleAccountTap(),
                    child: const SizedBox(
                      height: 32,
                      width: 32,
                      child: Icon(Icons.qr_code),
                    )),
              )
            : Container(),
        (_phase == FamilyPhase.parentHasDevices ||
                _phase == FamilyPhase.lockedNoPerms ||
                _phase == FamilyPhase.lockedActive)
            ? Padding(
                padding: const EdgeInsets.all(8.0),
                child: MiniCard(
                    onTap: _handleLockTap(),
                    child: SizedBox(
                      height: 32,
                      width: 32,
                      child: Icon((_phase.isLocked() || _hasThisDevice)
                          ? Icons.lock
                          : Icons.lock_open),
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
            _phase == FamilyPhase.parentHasDevices
                ? StageModal.accountLink
                : StageModal.accountChange);
      });
    };
  }

  _handleLockTap() {
    return () {
      traceAs("tappedLock", (trace) async {
        await _stage.showModal(trace, StageModal.lock);
      });
    };
  }

  _handleCtaTap() {
    return () {
      traceAs("tappedCta", (trace) async {
        if (_phase.requiresPerms()) {
          await _stage.showModal(trace, StageModal.perms);
        } else if (_phase.requiresActivation()) {
          await _stage.showModal(trace, StageModal.payment);
        } else if (!_hasThisDevice) {
          await _stage.showModal(trace, StageModal.onboardingAccountDecided);
        } else {
          await _stage.showModal(trace, StageModal.accountLink);
        }
      });
    };
  }

  String _getCtaText() {
    if (_phase.requiresPerms()) {
      return "Finish setup";
    } else if (_phase.requiresActivation()) {
      return "Activate";
    } else {
      return "Add a device";
    }
  }
}
