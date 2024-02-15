import 'package:common/app/app.dart';
import 'package:common/common/widget/family/home/animated_bg.dart';
import 'package:common/common/widget/family/home/this_device_onboard.dart';
import 'package:common/service/I18nService.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:relative_scale/relative_scale.dart';
import 'package:vistraced/via.dart';

import '../../../../app/channel.pg.dart';
import '../../../../family/devices.dart';
import '../../../../family/family.dart';
import '../../../../stage/channel.pg.dart';
import '../../../../ui/crash/crash_screen.dart';
import '../../../../ui/debug/commanddialog.dart';
import '../../../../ui/rate/rate_screen.dart';
import '../../../../util/di.dart';
import '../../../../util/trace.dart';
import '../../../model.dart';
import '../../../widget.dart';
import '../../lock/lock_screen.dart';
import '../onboard/family_onboard_screen.dart';
import '../smart_header/smart_footer.dart';
import '../smart_header/smart_header.dart';
import 'bg.dart';
import 'big_logo.dart';
import 'cta_buttons.dart';
import 'devices.dart';
import 'smart_onboard.dart';
import 'status_texts.dart';

part 'home_screen.g.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _$HomeScreenState();
}

@Injected(onlyVia: true, immediate: true)
class HomeScreenState extends State<HomeScreen>
    with
        TickerProviderStateMixin,
        Traceable,
        TraceOrigin,
        WidgetsBindingObserver {
  late final _status = Via.as<AppStatus>()..also(rebuild);
  late final _phase = Via.as<FamilyPhase>()..also(rebuild);
  late final _devices = Via.as<FamilyDevices>()..also(rebuild);
  late final _modal = Via.as<StageModal?>()..also(overlay);

  @MatcherSpec(of: "stage")
  late final _ready = Via.as<bool>()..also(rebuild);

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

  rebuild() {
    setState(() => _working = _status.now.isWorking() || !_ready.now);
  }

  OverlayEntry? _overlayEntry;
  StageModal? _overlayForModal;

  overlay() {
    if (_overlayForModal == _modal.now) return;
    _overlayForModal = _modal.now;

    final overlay = _decideOverlay(_modal.now);
    if (overlay != null) {
      _overlayEntry = OverlayEntry(builder: (context) => overlay);
      Overlay.of(context).insert(_overlayEntry!);
    } else {
      _overlayEntry?.remove();
      _overlayEntry = null;
    }
    rebuild();
  }

  @override
  Widget build(BuildContext context) {
    final phase = _phase.now;
    final deviceCount = _devices.now.entries.length;

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
                      Devices(),
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
                  await _modal.set(StageModal.help);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  _buildLoadingSpinner(BuildContext context) {
    if (_working || _phase.now == FamilyPhase.starting) {
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
