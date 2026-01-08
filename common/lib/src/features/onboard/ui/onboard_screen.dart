import 'package:common/src/features/link/domain/link.dart';
import 'package:common/src/features/onboard/domain/onboard.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:common/src/shared/ui/minicard/minicard.dart';
import 'package:common/src/features/modal/ui/blur_background.dart';
import 'package:common/src/features/onboard/ui/background.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/app_variants/family/widget/home/big_icon.dart';
import 'package:common/src/shared/automation/ids.dart';
import 'package:flutter/gestures.dart';
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

  _openTos(bool tos) async {
    log(Markers.userTap).trace("tappedTosLink", (m) async {
      if (tos) {
        await _stage.openLink(LinkId.tos, m);
      } else {
        final link = Core.act.isFamily ? LinkId.privacy : LinkId.privacyCloud;
        await _stage.openLink(link, m);
      }
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

  Widget _buildTosPrivacyText(BuildContext context, String text,
      {TextAlign textAlign = TextAlign.center}) {
    // Define a regex pattern to find text between * markers
    final pattern = RegExp(r'\*(.*?)\*');
    final matches = pattern.allMatches(text);

    // If we don't have exactly two matches (for two links), return simple text
    if (matches.length != 2) {
      return Text(
        text.replaceAll('*', ''), // Remove markers
        textAlign: textAlign,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      );
    }

    // Extract link texts and their positions
    final tosLink = matches.elementAt(0).group(1)!;
    final privacyLink = matches.elementAt(1).group(1)!;

    // Split text into parts
    final parts = text.split('*');

    return RichText(
      textAlign: textAlign,
      text: TextSpan(
        style: const TextStyle(color: Colors.white, fontSize: 12),
        children: [
          TextSpan(text: parts[0]), // Text before first link
          TextSpan(
            text: tosLink,
            style: TextStyle(
              color: context.theme.accent,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()..onTap = () => _openTos(true),
          ),
          TextSpan(text: parts[2]), // Text between links
          TextSpan(
            text: privacyLink,
            style: TextStyle(
              color: context.theme.accent,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()..onTap = () => _openTos(false),
          ),
          TextSpan(text: parts[4]), // Text after second link
        ],
      ),
    );
  }
}
