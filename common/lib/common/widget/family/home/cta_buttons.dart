import 'package:common/common/widget/family/home/private_dns_sheet.dart';
import 'package:common/service/I18nService.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:vistraced/via.dart';

import '../../../../family/devices.dart';
import '../../../../lock/lock.dart';
import '../../../../stage/channel.pg.dart';
import '../../../../util/trace.dart';
import '../../../model.dart';
import '../../../widget.dart';
import 'add_device_sheet.dart';
import 'guest_sheet.dart';
import 'totalcounter.dart';

part 'cta_buttons.g.dart';

class CtaButtons extends StatefulWidget {
  CtaButtons({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _$CtaButtonsState();
}

@Injected(onlyVia: true, immediate: true)
class CtaButtonsState extends State<CtaButtons>
    with
        ViaTools<CtaButtons>,
        TickerProviderStateMixin,
        Traceable,
        TraceOrigin {
  @MatcherSpec(of: "familyUnlink")
  late final _unlink = Via.call();
  late final _devices = Via.as<FamilyDevices>()..also(rebuild);
  late final _phase = Via.as<FamilyPhase>()..also(rebuild);
  late final _lock = Via.as<LockStore>()..also(rebuild);
  late final _modal = Via.as<StageModal?>();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: //_buildTotalCounter() +
          _buildBigCtaButton(context) +
              _buildSmallCtaButton(context) +
              _buildScanQrButton(context) +
              _buildLockButton(context),
      //_buildGuestButton(context),
    );
  }

  List<Widget> _buildTotalCounter() {
    // Total counter shown only when everything is set up
    if (_phase.now == FamilyPhase.parentHasDevices) {
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
    if (_phase.now.requiresAction()) {
      return [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: MiniCard(
              onTap: _handleCtaTap(),
              color: context.theme.accent,
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
        ),
      ];
    }

    return [];
  }

  // Small CTA icon shown only after onboarded
  List<Widget> _buildSmallCtaButton(BuildContext context) {
    final p = _phase.now;
    var canAddDevices = !p.requiresAction() && p.isParent() && !p.isLocked();
    canAddDevices = false;

    if (canAddDevices) {
      return [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: MiniCard(
              onTap: _handleCtaTap(),
              color: context.theme.accent,
              child: const SizedBox(
                height: 32,
                width: 32,
                child: Icon(CupertinoIcons.plus_circle, color: Colors.white),
              )),
        )
      ];
    }

    return [];
  }

  // Small lock QR icon shown only when onboarding
  List<Widget> _buildScanQrButton(BuildContext context) {
    final p = _phase.now;
    if (p == FamilyPhase.fresh || p == FamilyPhase.parentNoDevices) {
      return [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: MiniCard(
              onTap: _handleAccountTap,
              child: const SizedBox(
                height: 32,
                width: 32,
                child: Icon(CupertinoIcons.qrcode_viewfinder),
              )),
        )
      ];
    }

    return [];
  }

  // Lock icon shown almost always
  List<Widget> _buildLockButton(BuildContext context) {
    if (_phase.now.isLockable()) {
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

  List<Widget> _buildGuestButton(BuildContext context) {
    if (_phase.now == FamilyPhase.parentHasDevices ||
        _phase.now == FamilyPhase.parentNoDevices) {
      return [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: MiniCard(
              // color: context.theme.family,
              onTap: _handleGuestTap,
              child: SizedBox(
                height: 32,
                width: 32,
                // child: Icon(CupertinoIcons.lock_shield_fill),
                child: (!_lock.now.hasPin)
                    ? Icon(CupertinoIcons.lock_shield)
                    : Icon(CupertinoIcons.lock_shield_fill,
                        color: context.theme.accent),
              )),
        )
      ];
    }

    return [];
  }

  _handleAccountTap() {
    traceAs("tappedAccountQr", (trace) async {
      await _modal.set(_phase.now == FamilyPhase.parentHasDevices
          ? StageModal.accountLink
          : StageModal.accountChange);
    });
  }

  _handleGuestTap() {
    showCupertinoModalBottomSheet(
      context: context,
      backgroundColor: context.theme.bgColorCard,
      duration: const Duration(milliseconds: 300),
      builder: (context) => GuestSheet(),
    );
  }

  _handleLockTap() {
    return () {
      traceAs("tappedLock", (trace) async {
        await _modal.set(StageModal.lock);
      });
    };
  }

  _handleCtaTap() {
    return () {
      traceAs("tappedCta", (trace) async {
        final p = _phase.now;
        if (p == FamilyPhase.linkedUnlocked) {
          await _unlink.call();
          return;
        } else if (p == FamilyPhase.linkedNoPerms && !_lock.now.hasPin) {
          await _modal.set(StageModal.lock);
        } else if (p.requiresPerms()) {
          // await _modal.set(StageModal.perms);
          showCupertinoModalBottomSheet(
            context: context,
            duration: const Duration(milliseconds: 300),
            backgroundColor: context.theme.bgColorCard,
            builder: (context) => PrivateDnsSheet(),
          );
        } else if (p.requiresActivation()) {
          await _modal.set(StageModal.payment);
          // } else if (!_devices.now.hasThisDevice) {
          // await _modal.set(StageModal.onboardingAccountDecided);
        } else {
          // await _modal.set(StageModal.accountLink);
          showCupertinoModalBottomSheet(
            context: context,
            duration: const Duration(milliseconds: 300),
            backgroundColor: context.theme.bgColorCard,
            builder: (context) => AddDeviceSheet(),
          );
        }
      });
    };
  }

  String _getCtaText() {
    final p = _phase.now;
    if (p == FamilyPhase.linkedUnlocked) {
      return "family account cta unlink".i18n;
    } else if (p.requiresPerms()) {
      return "family cta action finish setup".i18n;
    } else if (p.requiresActivation()) {
      return "family cta action activate".i18n;
    } else {
      return "family cta action add device".i18n;
    }
  }
}
