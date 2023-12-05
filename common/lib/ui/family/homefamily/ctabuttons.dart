import 'package:flutter/cupertino.dart';
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
import '../family_totalcounter.dart';

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
  final _lock = dep<LockStore>();

  late FamilyPhase _phase;
  late bool _hasThisDevice;
  late bool _hasPin;
  late bool _isLocked;

  @override
  void initState() {
    super.initState();

    autorun((_) {
      setState(() {
        _phase = _family.phase;
        _hasThisDevice = _family.hasThisDevice;
        _hasPin = _lock.hasPin;
        _isLocked = _lock.isLocked;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: //_buildTotalCounter() +
          _buildBigCtaButton(context) +
              _buildSmallCtaButton(context) +
              _buildScanQrButton(context) +
              _buildLockButton(context),
    );
  }

  List<Widget> _buildTotalCounter() {
    // Total counter shown only when everything is set up
    if (_phase == FamilyPhase.parentHasDevices) {
      return [
        Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: FamilyTotalCounter(autoRefresh: true),
        ),
        Expanded(child: Container()),
      ];
    }

    return [];
  }

  // Big CTA button shown during onboarding
  List<Widget> _buildBigCtaButton(BuildContext context) {
    final theme = Theme.of(context).extension<BlokadaTheme>()!;

    if (_phase.requiresAction()) {
      return [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: MiniCard(
              onTap: _handleCtaTap(),
              color: theme.family,
              child: SizedBox(
                height: 32,
                child: Center(
                  child: Text(
                    _getCtaText(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        )
      ];
    }

    return [];
  }

  // Small CTA icon shown only after onboarded
  List<Widget> _buildSmallCtaButton(BuildContext context) {
    final theme = Theme.of(context).extension<BlokadaTheme>()!;

    final canAddDevices =
        !_phase.requiresAction() && _phase.isParent() && !_phase.isLocked();
    final canBeUnlinked = _phase == FamilyPhase.linkedUnlocked;

    if (canAddDevices || canBeUnlinked) {
      return [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: MiniCard(
              onTap: _handleCtaTap(),
              color: theme.family,
              child: SizedBox(
                height: 32,
                width: 32,
                child: Icon(
                    canBeUnlinked
                        ? CupertinoIcons.link
                        : CupertinoIcons.plus_circle,
                    color: Colors.white),
              )),
        )
      ];
    }

    return [];
  }

  // Small lock QR icon shown only when onboarding
  List<Widget> _buildScanQrButton(BuildContext context) {
    final theme = Theme.of(context).extension<BlokadaTheme>()!;

    if (_phase == FamilyPhase.fresh || _phase == FamilyPhase.parentNoDevices) {
      return [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: MiniCard(
              onTap: _handleAccountTap(),
              child: const SizedBox(
                height: 32,
                width: 32,
                child: Icon(CupertinoIcons.qrcode),
              )),
        )
      ];
    }

    return [];
  }

  // Lock icon shown almost always
  List<Widget> _buildLockButton(BuildContext context) {
    final theme = Theme.of(context).extension<BlokadaTheme>()!;

    if (_phase.isLockable()) {
      return [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: MiniCard(
              onTap: _handleLockTap(),
              child: const SizedBox(
                height: 32,
                width: 32,
                child: Icon(CupertinoIcons.lock_fill),
              )),
        )
      ];
    }

    return [];
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
        if (_phase == FamilyPhase.linkedUnlocked) {
          await _family.unlink(trace);
          return;
        } else if (_phase == FamilyPhase.linkedNoPerms && !_hasPin) {
          await _stage.showModal(trace, StageModal.lock);
        } else if (_phase.requiresPerms()) {
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
