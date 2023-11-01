import 'package:common/ui/family/family_scaffolding.dart';
import 'package:flutter/material.dart';

import '../../../family/family.dart';
import '../../../family/model.dart';
import '../../../stage/stage.dart';
import '../../../stats/stats.dart';
import '../../../util/di.dart';
import '../../../util/trace.dart';
import '../../minicard/chart.dart';
import '../../minicard/header.dart';
import '../../minicard/minicard.dart';
import '../../minicard/summary.dart';
import '../../theme.dart';

class HomeDevice extends StatefulWidget {
  final void Function()? onLongPress;
  final FamilyDevice device;
  final Color color;

  HomeDevice({
    Key? key,
    this.onLongPress,
    required this.device,
    required this.color,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _HomeCounterState();
  }
}

class _HomeCounterState extends State<HomeDevice>
    with TickerProviderStateMixin, TraceOrigin {
  final _stage = dep<StageStore>();
  final _stats = dep<StatsStore>();

  @override
  void initState() {
    super.initState();
  }

  _onTap() {
    traceAs("tappedSlideToStats", (trace) async {
      if (widget.device.deviceName.isEmpty) return;
      await _stats.setSelectedDevice(
          trace, widget.device.deviceName, widget.device.thisDevice);
      await _stage.setRoute(trace, pathHomeStats);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<BlokadaTheme>()!;
    return GestureDetector(
      onLongPress: widget.onLongPress,
      child: MiniCard(
        onTap: _onTap,
        // outlined: widget.thisDevice,
        outlined: false,
        child: MiniCardSummary(
          header: MiniCardHeader(
            text: widget.device.deviceDisplayName,
            icon: widget.device.thisDevice
                ? Icons.phonelink_lock
                : Icons.phone_iphone,
            color: widget.color,
            chevronIcon: Icons.chevron_right,
          ),
          big: IgnorePointer(
            ignoring: true,
            child: MiniCardChart(device: widget.device, color: widget.color),
          ),
          small: "",
          //footer: "home status detail active".i18n.replaceAll("*", ""),
        ),
      ),
    );
  }
}
