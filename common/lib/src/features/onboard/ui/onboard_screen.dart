import 'package:common/src/features/onboard/domain/onboard.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:common/src/shared/ui/minicard/minicard.dart';
import 'package:common/src/features/modal/ui/blur_background.dart';
import 'package:common/src/features/onboard/ui/background.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/app_variants/family/widget/home/big_icon.dart';
import 'package:common/src/shared/automation/ids.dart';
import 'package:flutter/material.dart';

import 'package:common/src/platform/stage/stage.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  OnboardingScreenState createState() => OnboardingScreenState();
}

class OnboardingScreenState extends State<OnboardingScreen> with Logging {
  final _stage = Core.get<StageStore>();
  final _onboard = Core.get<OnboardActor>();

  final GlobalKey<BlurBackgroundState> bgStateKey = GlobalKey();

  @override
  void initState() {
    super.initState();
  }

  _close() async {
    log(Markers.userTap).trace("tappedCloseOverlay", (m) async {
      await _stage.dismissModal(m);
      await _onboard.markIntroSeen(m);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          ColorfulBackground(),
          BlurBackground(
            key: bgStateKey,
            canClose: () => false,
            onClosed: _close,
            child: Semantics(
              identifier: AutomationIds.onboardIntroSheet,
              container: true,
              explicitChildNodes: true,
              child: Container(
                constraints: const BoxConstraints(maxWidth: maxContentWidth),
                child: _getFirstTimeScreen(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _getFirstTimeScreen(BuildContext context) {
    final header = "onboard header".i18n;

    // Fills the screen, with the room left split evenly above and below the
    // logo; scrolls instead when large text or a short screen needs more room.
    // spaceBetween rather than Spacers, which can't flex in a scroll view.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        primary: false,
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(height: 40),
              BigIcon(icon: null, canShowLogo: true),
              Column(
                children: [
                  Text(header,
                      textAlign: TextAlign.center,
                      style: context.theme.text.hero.copyWith(color: Colors.white)),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36.0),
                    child: Text("onboard desc".i18n,
                        textAlign: TextAlign.left,
                        style: context.theme.text.body.copyWith(color: Colors.white)),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 36.0, vertical: 8.0),
                          child: Semantics(
                            identifier: AutomationIds.onboardContinue,
                            button: true,
                            child: MiniCard(
                              onTap: _close,
                              color: context.theme.accent,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(minHeight: 32),
                                child: Center(
                                  child: Text(
                                    "universal action continue".i18n,
                                    style: TextStyle(
                                      color: context.theme.onAccent,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 60),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

}
