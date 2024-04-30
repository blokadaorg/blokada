import 'dart:async';

import 'package:common/common/model.dart';
import 'package:common/common/widget/common_card.dart';
import 'package:common/common/widget/common_clickable.dart';
import 'package:common/common/widget/common_divider.dart';
import 'package:common/common/widget/common_item.dart';
import 'package:common/common/widget/minicard/header.dart';
import 'package:common/common/widget/minicard/minicard.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/dragon/device/controller.dart';
import 'package:common/dragon/device/selected_device.dart';
import 'package:common/dragon/family/family.dart';
import 'package:common/dragon/filter/selected_filters.dart';
import 'package:common/dragon/widget/bottom_sheet.dart';
import 'package:common/dragon/widget/dialog.dart';
import 'package:common/dragon/widget/home/link_device_sheet.dart';
import 'package:common/dragon/widget/navigation.dart';
import 'package:common/dragon/widget/profile_utils.dart';
import 'package:common/dragon/widget/stats/radial_segment.dart';
import 'package:common/util/di.dart';
import 'package:common/util/mobx.dart';
import 'package:common/util/trace.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class DeviceSection extends StatefulWidget {
  final DeviceTag tag;

  const DeviceSection({Key? key, required this.tag}) : super(key: key);

  @override
  State<DeviceSection> createState() => DeviceSectionState();
}

class DeviceSectionState extends State<DeviceSection> with TraceOrigin {
  late final _family = dep<FamilyStore>();
  late final _device = dep<DeviceController>();
  late final _selectedFilters = dep<SelectedFilters>();
  late final _selectedDevice = dep<SelectedDeviceTag>();

  late FamilyDevice device;

  late StreamSubscription _subscription;

  bool built = false;

  @override
  void initState() {
    super.initState();
    reactionOnStore((_) => _family.devices, (_) => rebuild());
    _subscription = _selectedFilters.onChange.listen((_) => rebuild());
    _selectedDevice.now = widget.tag;
  }

  rebuild() {
    if (!mounted) return;
    if (!built) return;
    setState(() {});
  }

  @override
  void dispose() {
    _selectedDevice.now = null;
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    built = true;
    device = _family.devices.getDevice(widget.tag);

    return ListView(
      primary: true,
      children: [
        SizedBox(height: getTopPadding(context)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child:
              Text("STATISTICS", style: TextStyle(fontWeight: FontWeight.w500)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text("See the recent activity of this device.",
              style: TextStyle(color: context.theme.textSecondary)),
        ),
        SizedBox(
          //width: width > 600 ? 600 : width,
          width: 600,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: MiniCard(
              onTap: () {
                Navigation.open(context, Paths.deviceStats, arguments: device);
              },
              child: IgnorePointer(
                ignoring: true,
                child: Column(
                  children: [
                    const MiniCardHeader(
                      text: "Activity",
                      icon: CupertinoIcons.chart_bar,
                      color: Color(0xff33c75a),
                      chevronIcon: Icons.chevron_right,
                    ),
                    const SizedBox(height: 4),
                    RadialSegment(stats: device.stats),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text("DEVICE SETTINGS",
              style: TextStyle(fontWeight: FontWeight.w500)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text("Edit the blocking profile to apply for this device.",
              style: TextStyle(color: context.theme.textSecondary)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: CommonCard(
            child: Column(
              children: [
                Column(
                  children: [
                    (device.thisDevice)
                        ? Container()
                        : CommonItem(
                            onTap: () {
                              showRenameDialog(
                                  context, "device", device.device.alias,
                                  onConfirm: (name) {
                                _device.renameDevice(device.device, name);
                              });
                            },
                            icon: CupertinoIcons.device_phone_portrait,
                            text: "Name",
                            trailing: Text(device.device.alias,
                                style: TextStyle(
                                    color: context.theme.textSecondary)),
                          ),
                    CommonItem(
                      onTap: () {
                        showSelectProfileDialog(context, device: device.device);
                      },
                      icon: CupertinoIcons.person_crop_circle,
                      text: "Blocklist Profile",
                      trailing: Row(
                        children: [
                          Icon(getProfileIcon(device.profile.template),
                              color: getProfileColor(device.profile.template),
                              size: 18),
                          const SizedBox(width: 4),
                          Text(device.profile.displayAlias,
                              style: TextStyle(
                                color: getProfileColor(device.profile.template),
                              )),
                        ],
                      ),
                    ),
                    CommonItem(
                      onTap: () {
                        Navigation.open(context, Paths.deviceFilters,
                            arguments: device);
                      },
                      icon: CupertinoIcons.shield,
                      text: "Blocklists",
                      trailing: Text(
                          "${_selectedFilters.now.map((e) => e.options.length).sum()} selected",
                          style: TextStyle(
                            color: context.theme.textSecondary,
                          )),
                    ),
                    const SizedBox(height: 8),
                    const CommonDivider(indent: 0),
                    CommonItem(
                      onTap: () {},
                      icon: CupertinoIcons.time,
                      text: "Pause blocking",
                      chevron: false,
                      trailing: CupertinoSwitch(
                        activeColor: context.theme.accent,
                        value: device.device.mode == JsonDeviceMode.off,
                        onChanged: (bool? value) {
                          print(
                              "changing pause device ${device.device.deviceTag}");
                          _device.pauseDevice(device.device, value ?? false);
                          //setState(() {});
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        device.thisDevice
            ? Container()
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: CommonClickable(
                  onTap: () {
                    showSheet(
                      context,
                      builder: (context) =>
                          LinkDeviceSheet(device: device.device),
                    );
                  },
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text("Link this device again",
                      style: TextStyle(
                          color: context.theme.textSecondary,
                          fontSize: 16,
                          fontWeight: FontWeight.w500)),
                ),
              ),
        device.thisDevice
            ? Container()
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: CommonClickable(
                  onTap: () {
                    showConfirmDialog(context, device.displayName,
                        onConfirm: () {
                      Navigator.of(context).pop();
                      traceAs("deleteDevice", (trace) async {
                        await _family.deleteDevice(trace, device.device);
                      });
                    });
                  },
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: const Text("Delete this device",
                      style: TextStyle(
                          color: Colors.red,
                          fontSize: 16,
                          fontWeight: FontWeight.w500)),
                ),
              ),
        const SizedBox(height: 48),
      ],
    );
  }
}
