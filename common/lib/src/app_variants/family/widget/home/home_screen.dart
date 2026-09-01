import 'dart:async';

import 'package:common/src/shared/navigation.dart';
import 'package:common/src/features/home/ui/header/header.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/app_variants/family/module/family/family.dart';
import 'package:common/src/app_variants/family/widget/home/home_devices.dart';
import 'package:common/src/app_variants/family/widget/home/link_confirm.dart';
import 'package:common/src/app_variants/family/widget/home/smart_onboard.dart';
import 'package:common/src/platform/app/app.dart';
import 'package:common/src/platform/stage/stage.dart';
import 'package:common/src/util/mobx.dart';
import 'package:flutter/cupertino.dart';

class FamilyHomeScreen extends StatefulWidget {
  const FamilyHomeScreen({Key? key}) : super(key: key);

  @override
  State<FamilyHomeScreen> createState() => FamilyHomeScreenState();
}

class FamilyHomeScreenState extends State<FamilyHomeScreen>
    with TickerProviderStateMixin, Logging, WidgetsBindingObserver, Disposables {
  late final _app = Core.get<AppStore>();
  late final _stage = Core.get<StageStore>();
  late final _phase = Core.get<FamilyPhaseValue>();
  late final _devices = Core.get<FamilyDevicesValue>();
  late final _parentDeviceProtectionOwner = Core.get<ParentDeviceProtectionOwnerValue>();
  late final _pendingLink = Core.get<PendingLinkValue>();
  late final _link = Core.get<LinkActor>();
  String? _promptedFor;

  @override
  void initState() {
    super.initState();
    _app.addOn(appStatusChanged, rebuild);
    disposeLater(_phase.onChange.listen(rebuild));
    disposeLater(_devices.onChange.listen(rebuild));
    disposeLater(_parentDeviceProtectionOwner.onChange.listen(rebuild));
    reactionOnStore((_) => _stage.route, rebuild);
    reactionOnStore((_) => _stage.isReady, rebuild);
    disposeLater(_pendingLink.onChange.listen((_) => _resolvePendingLink()));
    // A link parked before this screen mounted (cold start from a QR scan or
    // a tapped link) emits no change event, so check once on mount too.
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolvePendingLink());
  }

  Future<void> _resolvePendingLink() async {
    final token = _pendingLink.present;
    if (token == null) {
      _promptedFor = null;
      return;
    }
    // Both the value listener and the post-frame callback can reach here for
    // the same token. Key the guard on the token so the dialog shows once.
    if (_promptedFor == token) return;
    _promptedFor = token;

    await log(Markers.ui).trace("resolvePendingLink", (m) async {
      final needsConfirm = await _link.needsConfirmation(m);
      // A newer link can replace the pending value while the predicate runs.
      // Only the resolve that still owns it may prompt or commit, so two links
      // never raise two prompts.
      if (_pendingLink.present != token) return;

      if (!needsConfirm) {
        await _finishPendingLink((m) => _link.confirmPendingLink(token, m));
        return;
      }
      // Unmounted before the prompt: release the link so a later scan of the
      // same token is not swallowed by an unanswerable parked value.
      if (!mounted) {
        await _link.cancelPendingLink(token, m);
        return;
      }
      // Not awaited on purpose: the dialog outlives this trace, and it resolves
      // its own outcome, treating a barrier dismissal as a cancel.
      unawaited(showLinkConfirmDialog(
        context,
        onConfirm: () =>
            _finishPendingLink((m) => _link.confirmPendingLink(token, m)),
        onCancel: () =>
            _finishPendingLink((m) => _link.cancelPendingLink(token, m)),
      ));
    });
  }

  // The dialog callbacks are fire-and-forget, so a throwing commit would raise
  // an unhandled async error. _commitLink already surfaces a fault modal.
  Future<void> _finishPendingLink(Future<void> Function(Marker) action) async {
    try {
      await log(Markers.ui).trace("finishPendingLink", (m) async {
        await action(m);
      });
    } catch (e) {
      // _commitLink already showed a fault modal, but never stay silent.
      log(Markers.ui).e(msg: "finishPendingLink failed", err: e);
    }
  }

  @override
  void dispose() {
    super.dispose();
    disposeAll();
  }

  @override
  Widget build(BuildContext context) {
    final phase = _phase.now;
    final parentDeviceProtectionOwner = _parentDeviceProtectionOwner.now;
    final deviceCount = _devices.now.visibleCount(parentDeviceProtectionOwner);

    return Stack(
      children: [
        Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: maxContentWidth),
            child: Column(
              children: [
                const SizedBox(height: 48),
                SmartOnboard(phase: phase, deviceCount: deviceCount),
              ],
            ),
          ),
        ),
        phase == FamilyPhase.parentHasDevices
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 120),
                  child: HomeDevices(
                    devices: _devices.now,
                    parentDeviceProtectionOwner: parentDeviceProtectionOwner,
                  ),
                ),
              )
            : Container(),
        Column(
          children: [
            const SizedBox(height: 48),
            SmartHeader(phase: phase),
          ],
        ),
      ],
    );
  }
}
