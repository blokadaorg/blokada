import 'package:common/app/app.dart';
import 'package:common/common/model.dart';
import 'package:common/common/widget/icon.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/dragon/family/family.dart';
import 'package:common/dragon/widget/home/animated_bg.dart';
import 'package:common/dragon/widget/home/devices.dart';
import 'package:common/dragon/widget/home/smart_onboard.dart';
import 'package:common/dragon/widget/onboard/family_onboard_screen.dart';
import 'package:common/dragon/widget/smart_header/smart_header.dart';
import 'package:common/service/I18nService.dart';
import 'package:common/stage/channel.pg.dart';
import 'package:common/stage/stage.dart';
import 'package:common/ui/crash/crash_screen.dart';
import 'package:common/ui/debug/commanddialog.dart';
import 'package:common/ui/lock/lock_screen.dart';
import 'package:common/ui/rate/rate_screen.dart';
import 'package:common/util/di.dart';
import 'package:common/util/mobx.dart';
import 'package:common/util/trace.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen>
    with
        TickerProviderStateMixin,
        Traceable,
        TraceOrigin,
        WidgetsBindingObserver {
  late final _app = dep<AppStore>();
  late final _family = dep<FamilyStore>();
  late final _stage = dep<StageStore>();

  var _working = true;

  late final _ctrl = PageController(initialPage: 0);
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      if (_ctrl.page == 1) {
        setState(() {
          _page = 1;
        });
      } else {
        setState(() {
          _page = 0;
        });
      }
    });
    WidgetsBinding.instance.addObserver(this);

    _app.addOn(appStatusChanged, (_) => rebuild());
    reactionOnStore((_) => _family.phase, (_) => rebuild());
    reactionOnStore((_) => _family.devices, (_) => rebuild());
    reactionOnStore((_) => _stage.route, (_) => rebuild());
    reactionOnStore((_) => _stage.isReady, (_) => rebuild());
  }

  rebuild() {
    if (!mounted) return;
    overlay();
    setState(() => _working = _app.status.isWorking() || !_stage.isReady);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      //_overlayForModal = null;
      overlay();
    }
  }

  OverlayEntry? _overlayEntry;
  StageModal? _overlayForModal;

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
  Widget build(BuildContext context) {
    final phase = _family.phase;
    final deviceCount = _family.devices.entries.length;

    return Scaffold(
        body: Stack(
      children: [
        AnimatedBg(),
        Stack(
          children: [
            Column(
              children: [
                SizedBox(height: 48),
                SmartOnboard(phase: phase, deviceCount: deviceCount),
                //SmartFooter(phase: phase, hasPin: true),
              ],
            ),
            phase == FamilyPhase.parentHasDevices
                ? ListView(
                    reverse: true,
                    children: [
                      Devices(devices: _family.devices),
                    ],
                  )
                : Container(),
            Column(
              children: [
                SizedBox(height: 48),
                SmartHeader(phase: phase),
              ],
            ),
          ],
        ),
      ],
    ));
  }

  Widget? _decideOverlay(StageModal? modal) {
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
        return null;
    }
  }
  // @override
  // Widget build(BuildContext context) {
  //   return Scaffold(
  //     body: FamilyBgWidget(
  //       child: Stack(
  //         children: [
  //           Container(
  //             child: Stack(
  //               alignment: Alignment.topCenter,
  //               children: [
  //                 const BigLogo(),
  //                 _buildHelpButton(),
  //                 AbsorbPointer(
  //                   absorbing: false,
  //                   child: Padding(
  //                     padding: const EdgeInsets.symmetric(horizontal: 8.0),
  //                     child: RelativeBuilder(
  //                         builder: (context, height, width, sy, sx) {
  //                       return Container(
  //                         constraints: const BoxConstraints(maxWidth: 500),
  //                         child: Stack(
  //                           alignment: Alignment.center,
  //                           children: [
  //                             // Main home screen content
  //                             Column(
  //                               mainAxisSize: MainAxisSize.max,
  //                               mainAxisAlignment: MainAxisAlignment.center,
  //                               children: [
  //                                 const Spacer(),
  //
  //                                 // Devices list or the status texts
  //                                 (_phase.now == FamilyPhase.parentHasDevices)
  //                                     ? const Devices()
  //                                     : StatusTexts(phase: _phase.now),
  //                                 CtaButtons(),
  //
  //                                 // Leave space for navbar
  //                                 // (!_phase.now.isLocked())
  //                                 //     ? SizedBox(height: sy(40))
  //                                 //     : Container(),
  //                                 SizedBox(height: sy(24)),
  //                               ],
  //                             ),
  //
  //                             // Loading spinner on covering the content
  //                             _buildLoadingSpinner(context),
  //                           ],
  //                         ),
  //                       );
  //                     }),
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ),
  //           OverlayContainer(modal: _modal.now),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  _buildHelpButton() {
    return GestureDetector(
      onDoubleTap: () => _showCommandDialog(context),
      child: Padding(
        padding: const EdgeInsets.only(top: 60, right: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            HomeIcon(
              icon: CupertinoIcons.question_circle,
              alwaysWhite: true,
              onTap: () {
                traceAs("tappedShowHelp", (trace) async {
                  await _stage.showModal(trace, StageModal.help);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  _buildLoadingSpinner(BuildContext context) {
    if (_working || _family.phase == FamilyPhase.starting) {
      return Column(children: [
        const Spacer(),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48.0),
            child: Column(
              children: [
                Text(
                  "",
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: context.theme.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  "home status detail progress".i18n + "\n\n",
                  style: TextStyle(
                      fontSize: 18, color: context.theme.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            )),
        const SizedBox(height: 72),
      ]);
    } else {
      return Container();
    }
  }

  Future<void> _showCommandDialog(BuildContext context) {
    return showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return CommandDialog();
        });
  }
}
