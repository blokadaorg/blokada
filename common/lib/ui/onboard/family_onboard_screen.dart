import 'package:common/service/I18nService.dart';
import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:mobx/mobx.dart';
import 'package:slide_to_act_reborn/slide_to_act_reborn.dart';

import '../../onboard/onboard.dart';
import '../../stage/channel.pg.dart';
import '../../stage/stage.dart';
import '../../util/di.dart';
import '../../util/trace.dart';
import '../overlay/blur_background.dart';

class FamilyOnboardScreen extends StatefulWidget {
  const FamilyOnboardScreen({Key? key}) : super(key: key);

  @override
  FamilyOnboardScreenState createState() => FamilyOnboardScreenState();
}

class FamilyOnboardScreenState extends State<FamilyOnboardScreen>
    with TraceOrigin {
  final _stage = dep<StageStore>();
  final _onboard = dep<OnboardStore>();

  late OnboardState _onboardState;

  final GlobalKey<BlurBackgroundState> bgStateKey = GlobalKey();
  final GlobalKey<SlideActionState> _slideUnlockKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    autorun((_) {
      setState(() {
        _onboardState = _onboard.onboardState;
      });
    });
  }

  void _onIntroEnd(context) {
    bgStateKey.currentState?.animateToClose();
  }

  _close() async {
    traceAs("tappedCloseOverlay", (trace) async {
      await _stage.setRoute(trace, StageKnownRoute.homeCloseOverlay.path);
    });
  }

  Widget _buildImage(String assetName, [double width = 150]) {
    return Image.asset('assets/$assetName', width: width);
  }

  @override
  Widget build(BuildContext context) {
    return BlurBackground(
      key: bgStateKey,
      onClosed: _close,
      child: _onboardState == OnboardState.firstTime
          ? _getFirstTimeScreen(context)
          : _getAccountIdDecidedScreen(context),
    );
  }

  Widget _getFirstTimeScreen(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Spacer(),
        Text("Welcome to Blokada Family!",
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              // fontWeight: FontWeight.w500,
            )),
        Spacer(),
        SizedBox(
          height: 80,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: SlideAction(
              key: _slideUnlockKey,
              onSubmit: () {
                Future.delayed(
                  Duration(milliseconds: 300),
                  () => bgStateKey.currentState?.animateToClose(),
                );
              },
              outerColor: Colors.white.withOpacity(0.2),
              innerColor: Colors.black.withOpacity(0.4),
              borderRadius: 12,
              elevation: 0,
              text: "Slide to unlock",
              textStyle: const TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
              sliderButtonIcon:
                  Icon(Icons.arrow_forward_ios, color: Colors.white),
              submittedIcon: Icon(Icons.lock_open, color: Colors.white),
              sliderRotate: false,
            ),
          ),
        ),
        const SizedBox(height: 60),
      ],
    );
  }

  Widget _getAccountIdDecidedScreen(BuildContext context) {
    const bodyStyle = TextStyle(fontSize: 16.0, color: Colors.white);

    const pageDecoration = PageDecoration(
      titleTextStyle: TextStyle(
          fontSize: 36.0, fontWeight: FontWeight.w900, color: Colors.white),
      bodyTextStyle: bodyStyle,
      bodyPadding: EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
      //pageColor: Colors.white,
      imagePadding: EdgeInsets.zero,
    );

    return IntroductionScreen(
      //key: introKey,
      globalBackgroundColor: Colors.transparent,
      // allowImplicitScrolling: true,
      // autoScrollDuration: 3000,
      // infiniteAutoScroll: true,
      // globalHeader: Align(
      //   alignment: Alignment.topRight,
      //   child: SafeArea(
      //     child: Padding(
      //       padding: const EdgeInsets.only(top: 32, right: 32),
      //       child: _buildImage('images/header.png', 150),
      //     ),
      //   ),
      // ),
      // globalFooter: SizedBox(
      //   width: double.infinity,
      //   height: 60,
      //   child: ElevatedButton(
      //     child: const Text(
      //       'Let\'s go right away!',
      //       style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
      //     ),
      //     onPressed: () => _onIntroEnd(context),
      //   ),
      // ),
      pages: [
        PageViewModel(
          title: "Welcome to Blokada Family!",
          body: "Here is the quick intro on how to set up the app.",
          image: _buildImage('images/blokada_logo.png'),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: "Step 1: parent device",
          body:
              "As a parent, activate the app on your device first. Then, take the note of your account ID in 'Settings tab -> My account'",
          image: _buildImage('images/blokada_logo.png'),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: "Step 2: child device",
          body:
              "Install the app on your child's device. Next, enter the account ID from the previous step, by going to 'Settings tab -> Restore account'.",
          image: _buildImage('images/blokada_logo.png'),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: "That's it!",
          body:
              "On your device, navigate to the 'Activity' tab to see the online traffic from both devices. Use the filters menu to see what your child is doing in real time.",
          image: _buildImage('images/blokada_logo.png'),
          // image: _buildImage('img2.jpg'),
          // footer: ElevatedButton(
          //   onPressed: () {
          //     //introKey.currentState?.animateScroll(0);
          //   },
          //   style: ElevatedButton.styleFrom(
          //     backgroundColor: Colors.lightBlue,
          //     shape: RoundedRectangleBorder(
          //       borderRadius: BorderRadius.circular(8.0),
          //     ),
          //   ),
          //   child: const Text(
          //     'FooButton',
          //     style: TextStyle(color: Colors.white),
          //   ),
          // ),
          decoration: pageDecoration,
          // decoration: pageDecoration.copyWith(
          //   bodyFlex: 6,
          //   imageFlex: 6,
          //   safeArea: 80,
          // ),
        ),
        // PageViewModel(
        //   title: "Title of last page - reversed",
        //   bodyWidget: const Row(
        //     mainAxisAlignment: MainAxisAlignment.center,
        //     children: [
        //       Text("Click on ", style: bodyStyle),
        //       Icon(Icons.edit),
        //       Text(" to edit a post", style: bodyStyle),
        //     ],
        //   ),
        //   decoration: pageDecoration.copyWith(
        //     bodyFlex: 2,
        //     imageFlex: 4,
        //     bodyAlignment: Alignment.bottomCenter,
        //     imageAlignment: Alignment.topCenter,
        //   ),
        //   image: _buildImage('img1.jpg'),
        //   reverse: true,
        // ),
      ],
      onDone: () => _onIntroEnd(context),
      onSkip: () => _onIntroEnd(context), // You can override onSkip callback
      showSkipButton: true,
      skipOrBackFlex: 1,
      nextFlex: 1,
      showBackButton: false,
      //rtl: true, // Display as right-to-left
      back: const Icon(Icons.arrow_back),
      skip: Text('universal action cancel'.i18n,
          style: const TextStyle(fontSize: 16, color: Colors.white)),
      next: Text("universal action continue".i18n,
          style: const TextStyle(fontSize: 16, color: Colors.white)),
      done: Text("universal action done".i18n,
          style: const TextStyle(fontSize: 16, color: Colors.white)),
      curve: Curves.fastLinearToSlowEaseIn,
      controlsMargin: const EdgeInsets.only(bottom: 64, left: 16, right: 16),
      controlsPadding: const EdgeInsets.fromLTRB(8.0, 4.0, 8.0, 4.0),
      dotsDecorator: const DotsDecorator(
        size: Size(10.0, 10.0),
        color: Colors.white30,
        activeColor: Colors.white,
        activeSize: Size(10.0, 10.0),
        activeShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(25.0)),
        ),
      ),
      dotsContainerDecorator: const ShapeDecoration(
        // color: Colors.black38,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8.0)),
        ),
      ),
    );
  }
}
