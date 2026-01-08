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
    // Make header font size smaller for long strings
    // Count only until the first line break
    final header = "onboard header".i18n;
    int lenUntilBreak = header.indexOf("\n");
    if (lenUntilBreak < 0) lenUntilBreak = header.length;
    final headerFontSize = (lenUntilBreak > 18) ? 24.0 : 32.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          const Spacer(),
          BigIcon(icon: null, canShowLogo: true),
          const Spacer(),
          Text(header,
              textAlign: TextAlign.center,
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                color: Colors.white,
                fontSize: headerFontSize,
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36.0),
            child: Text("onboard desc".i18n,
                textAlign: TextAlign.left,
                textScaler: TextScaler.noScaling,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  // fontWeight: FontWeight.w500,
                )),
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
                      child: SizedBox(
                        height: 32,
                        child: Center(
                          child: Text(
                            "universal action continue".i18n,
                            style: const TextStyle(
                              color: Colors.white,
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
    );
  }

}
