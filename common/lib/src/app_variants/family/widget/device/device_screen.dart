import 'dart:async';

import 'package:common/src/app_variants/family/module/device_v3/device.dart';
import 'package:common/src/app_variants/family/module/family/family.dart';
import 'package:common/src/app_variants/family/widget/device/device_section.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/features/filter/domain/filter.dart';
import 'package:common/src/shared/layout/with_detail_pane.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:flutter/material.dart';

/// Family per-device hub. On expanded windows the device settings are the
/// master pane with stats/blocklists/domain-detail alongside (initially
/// stats). Pane arguments are re-resolved from FamilyDevicesValue every
/// build so a profile or device change re-renders the pane with current
/// data, like the old per-screen builders which read fresh state.
class DeviceScreen extends StatefulWidget {
  final DeviceTag tag;

  const DeviceScreen({Key? key, required this.tag}) : super(key: key);

  @override
  State<DeviceScreen> createState() => DeviceScreenState();
}

class DeviceScreenState extends State<DeviceScreen> {
  late final _family = Core.get<FamilyDevicesValue>();
  late final _selectedFilters = Core.get<SelectedFilters>();

  late StreamSubscription _subscription;
  bool built = false;

  @override
  void initState() {
    super.initState();
    _subscription = _selectedFilters.onChange.listen((_) => rebuild());
  }

  rebuild() {
    if (!mounted) return;
    if (!built) return;
    setState(() {});
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    built = true;
    final device = _family.now.getDevice(widget.tag);

    return WithDetailPane(
      title: device.displayName,
      master: DeviceSection(tag: widget.tag),
      detailPaths: const {
        Paths.deviceStats,
        Paths.deviceStatsDetail,
        Paths.deviceFilters,
      },
      initialDetail: Paths.deviceStats,
      paneArguments: (path, arguments) => path == Paths.deviceStatsDetail
          ? arguments
          : _family.now.getDevice(widget.tag),
    );
  }
}
