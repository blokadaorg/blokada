import 'package:common/common/navigation.dart';
import 'package:common/common/widget/home/header/header.dart';
import 'package:common/core/core.dart';
import 'package:common/family/module/family/family.dart';
import 'package:common/family/widget/home/home_devices.dart';
import 'package:common/family/widget/home/smart_onboard.dart';
import 'package:common/platform/app/app.dart';
import 'package:common/platform/stage/stage.dart';
import 'package:common/util/mobx.dart';
import 'package:flutter/cupertino.dart';

class FamilyHomeScreen extends StatefulWidget {
  const FamilyHomeScreen({Key? key}) : super(key: key);

  @override
  State<FamilyHomeScreen> createState() => FamilyHomeScreenState();
}

class FamilyHomeScreenState extends State<FamilyHomeScreen>
    with
        TickerProviderStateMixin,
        Logging,
        WidgetsBindingObserver,
        Disposables {
  late final _app = Core.get<AppStore>();
  late final _stage = Core.get<StageStore>();
  late final _phase = Core.get<FamilyPhaseValue>();
  late final _devices = Core.get<FamilyDevicesValue>();

  @override
  void initState() {
    super.initState();
    _app.addOn(appStatusChanged, rebuild);
    disposeLater(_phase.onChange.listen(rebuild));
    disposeLater(_devices.onChange.listen(rebuild));
    reactionOnStore((_) => _stage.route, rebuild);
    reactionOnStore((_) => _stage.isReady, rebuild);
  }

  @override
  void dispose() {
    super.dispose();
    disposeAll();
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
}
