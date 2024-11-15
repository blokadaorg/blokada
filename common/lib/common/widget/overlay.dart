import 'package:common/common/widget/lock/lock_screen.dart';
import 'package:common/common/widget/rate/rate_screen.dart';
import 'package:common/core/core.dart';
import 'package:common/family/widget/onboard/family_onboard_screen.dart';
import 'package:common/platform/stage/channel.pg.dart';
import 'package:common/platform/stage/stage.dart';
import 'package:common/util/mobx.dart';
import 'package:flutter/material.dart';

class OverlaySheet extends StatefulWidget {
  const OverlaySheet({super.key});

  @override
  State<StatefulWidget> createState() => OverlaySheetState();
}

class OverlaySheetState extends State<OverlaySheet>
    with WidgetsBindingObserver {
  late final _stage = dep<StageStore>();

  OverlayEntry? _overlayEntry;
  StageModal? _overlayForModal;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    reactionOnStore((_) => _stage.route, (_) => rebuild());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  rebuild() {
    if (!mounted) return;
    overlay();
  }

  overlay() {
    if (_overlayForModal == _stage.route.modal) return;
    _overlayForModal = _stage.route.modal;

    final overlay = _decideOverlay(_stage.route.modal);
    if (overlay != null) {
      _overlayEntry?.remove();
      _overlayEntry = OverlayEntry(builder: (context) => overlay);
      Overlay.of(context).insert(_overlayEntry!);
    } else {
      _overlayEntry?.remove();
      _overlayEntry = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      //_overlayForModal = null;
      overlay();
    }
  }

  Widget? _decideOverlay(StageModal? modal) {
    switch (modal) {
      case StageModal.lock:
        return const LockScreen();
      case StageModal.rate:
        return const RateScreen();
      case StageModal.onboardingFamily:
        return const FamilyOnboardScreen();
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) => Container();
}
