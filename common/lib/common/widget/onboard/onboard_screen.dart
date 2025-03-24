import 'package:common/common/module/link/link.dart';
import 'package:common/common/module/onboard/onboard.dart';
import 'package:common/common/widget/minicard/minicard.dart';
import 'package:common/common/widget/onboard/background.dart';
import 'package:common/common/widget/overlay/blur_background.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/core/core.dart';
import 'package:common/common/navigation.dart';
import 'package:common/family/widget/home/big_icon.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../platform/stage/stage.dart';

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
      await _onboard.markOnboardSeen(m);
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
            child: Container(
              constraints: const BoxConstraints(maxWidth: maxContentWidth),
              child: _getFirstTimeScreen(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _getFirstTimeScreen(BuildContext context) {
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
          Text("onboard header".i18n,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36.0),
            child: Text("onboard desc".i18n,
                textAlign: TextAlign.left,
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
                  padding: const EdgeInsets.symmetric(horizontal: 36.0, vertical: 8.0),
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
            ],
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildTosPrivacyText(BuildContext context, String text, {TextAlign textAlign = TextAlign.center}) {
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
            recognizer: TapGestureRecognizer()
              ..onTap = () => _openTos(true),
          ),
          TextSpan(text: parts[2]), // Text between links
          TextSpan(
            text: privacyLink,
            style: TextStyle(
              color: context.theme.accent,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () => _openTos(false),
          ),
          TextSpan(text: parts[4]), // Text after second link
        ],
      ),
    );
  }
}
