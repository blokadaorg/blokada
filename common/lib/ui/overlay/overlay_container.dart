import 'package:flutter/material.dart';

import '../../stage/channel.pg.dart';
import '../crash/crash_screen.dart';
import '../lock/lock_screen.dart';
import '../family/onboard/family_onboard_screen.dart';
import '../rate/rate_screen.dart';

class OverlayContainer extends StatelessWidget {
  const OverlayContainer({super.key, required this.modal});

  final StageModal? modal;

  @override
  Widget build(BuildContext context) {
    return _decideOverlay(modal);
  }

  Widget _decideOverlay(StageModal? modal) {
    switch (modal) {
      case StageModal.crash:
        return const CrashScreen();
      case StageModal.lock:
        return const LockScreen();
      case StageModal.rate:
        return const RateScreen();
      case StageModal.onboardingFamily:
        return const FamilyOnboardScreen();
      default:
        return Container();
    }
  }
}
