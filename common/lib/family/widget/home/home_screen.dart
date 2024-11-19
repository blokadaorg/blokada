import 'package:common/common/model/model.dart';
import 'package:common/common/navigation.dart';
import 'package:common/common/widget/home/header/header.dart';
import 'package:common/common/widget/icon.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/core/core.dart';
import 'package:common/family/module/family/family.dart';
import 'package:common/family/widget/home/home_devices.dart';
import 'package:common/family/widget/home/smart_onboard.dart';
import 'package:common/platform/app/app.dart';
import 'package:common/platform/stage/channel.pg.dart';
import 'package:common/platform/stage/stage.dart';
import 'package:common/util/mobx.dart';
import 'package:flutter/cupertino.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen>
    with
        TickerProviderStateMixin,
        Logging,
        WidgetsBindingObserver,
        Disposables {
  late final _app = DI.get<AppStore>();
  late final _stage = DI.get<StageStore>();
  late final _phase = DI.get<FamilyPhaseValue>();
  late final _devices = DI.get<FamilyDevicesValue>();

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

    _app.addOn(appStatusChanged, rebuild);
    disposeLater(_phase.onChange.listen(rebuild));
    disposeLater(_devices.onChange.listen(rebuild));
    reactionOnStore((_) => _stage.route, rebuild);
    reactionOnStore((_) => _stage.isReady, rebuild);
  }

  @override
  rebuild(dynamic it) {
    if (!mounted) return;
    setState(() => _working = _app.status.isWorking() || !_stage.isReady);
  }

  @override
  Widget build(BuildContext context) {
    final phase = _phase.now;
    final deviceCount = _devices.now.entries.length;

    return Stack(
      children: [
        Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: maxContentWidth),
            child: Column(
              children: [
                const SizedBox(height: 48),
                SmartOnboard(phase: phase, deviceCount: deviceCount),
                //SmartFooter(phase: phase, hasPin: true),
              ],
            ),
          ),
        ),
        phase == FamilyPhase.parentHasDevices
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 120),
                  child: HomeDevices(devices: _devices.now),
                ),
              )
            : Container(),
        Column(
          children: [
            const SizedBox(height: 48),
            SmartHeader(phase: phase),
          ],
        ),
      ],
    );
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
      child: Padding(
        padding: const EdgeInsets.only(top: 60, right: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            HomeIcon(
              icon: CupertinoIcons.question_circle,
              alwaysWhite: true,
              onTap: () {
                log(Markers.userTap).trace("tappedShowHelp", (m) async {
                  await _stage.showModal(StageModal.help, m);
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
}
