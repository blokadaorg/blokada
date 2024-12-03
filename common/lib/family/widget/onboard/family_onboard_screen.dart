import 'package:common/common/widget/overlay/blur_background.dart';
import 'package:common/core/core.dart';
import 'package:common/common/navigation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:slide_to_act_reborn/slide_to_act_reborn.dart';

import '../../../platform/stage/stage.dart';

class FamilyOnboardScreen extends StatefulWidget {
  const FamilyOnboardScreen({Key? key}) : super(key: key);

  @override
  FamilyOnboardScreenState createState() => FamilyOnboardScreenState();
}

class FamilyOnboardScreenState extends State<FamilyOnboardScreen> with Logging {
  final _stage = Core.get<StageStore>();

  final GlobalKey<BlurBackgroundState> bgStateKey = GlobalKey();
  final GlobalKey<SlideActionState> _slideUnlockKey = GlobalKey();

  @override
  void initState() {
    super.initState();
  }

  void _onIntroEnd(context) {
    bgStateKey.currentState?.animateToClose();
  }

  _close() async {
    log(Markers.userTap).trace("tappedCloseOverlay", (m) async {
      await _stage.dismissModal(m);
    });
  }

  Widget _buildImage(String assetName, [double width = 150]) {
    return Image.asset('assets/$assetName', width: width);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: BlurBackground(
        key: bgStateKey,
        onClosed: _close,
        child: Container(
          constraints: const BoxConstraints(maxWidth: maxContentWidth),
          child: _getFirstTimeScreen(context),
        ),
      ),
    );
  }

  Widget _getFirstTimeScreen(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Spacer(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 68.0),
          child: Column(
            children: [
              Text("family onboard header".i18n,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    // fontWeight: FontWeight.w500,
                  )),
              const SizedBox(height: 24),
              Text("family onboard body".i18n,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    // fontWeight: FontWeight.w500,
                  )),
            ],
          ),
        ),
        const Spacer(),
        // GestureDetector(
        //   onTap: _openTos,
        //   child: const Padding(
        //     padding: EdgeInsets.symmetric(horizontal: 68.0, vertical: 16.0),
        //     child: Text(
        //         "By continuing you agree to our Terms of Service and Privacy Policy.",
        //         textAlign: TextAlign.center,
        //         style: TextStyle(
        //           color: Colors.white,
        //           fontSize: 12,
        //           // fontWeight: FontWeight.w500,
        //         )),
        //   ),
        // ),
        SizedBox(
          height: 80,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: SlideAction(
              key: _slideUnlockKey,
              onSubmit: () {
                Future.delayed(
                  const Duration(milliseconds: 300),
                  () => bgStateKey.currentState?.animateToClose(),
                );
              },
              outerColor: Colors.white.withOpacity(0.2),
              innerColor: Colors.black.withOpacity(0.4),
              borderRadius: 12,
              elevation: 0,
              text: "lock action slide unlock".i18n,
              textStyle: const TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
              sliderButtonIcon:
                  const Icon(CupertinoIcons.chevron_right, color: Colors.white),
              submittedIcon:
                  const Icon(CupertinoIcons.chevron_right, color: Colors.white),
              sliderRotate: false,
            ),
          ),
        ),
        const SizedBox(height: 60),
      ],
    );
  }
}
