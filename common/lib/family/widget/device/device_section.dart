import 'package:common/common/dialog.dart';
import 'package:common/common/model/model.dart';
import 'package:common/common/module/filter/filter.dart';
import 'package:common/common/navigation.dart';
import 'package:common/common/widget/bottom_sheet.dart';
import 'package:common/common/widget/common_card.dart';
import 'package:common/common/widget/common_clickable.dart';
import 'package:common/common/widget/common_divider.dart';
import 'package:common/common/widget/common_item.dart';
import 'package:common/common/widget/minicard/header.dart';
import 'package:common/common/widget/minicard/minicard.dart';
import 'package:common/common/widget/stats/radial_segment.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/core/core.dart';
import 'package:common/family/module/customlist_v3/customlist.dart';
import 'package:common/family/module/device_v3/device.dart';
import 'package:common/family/module/family/family.dart';
import 'package:common/family/widget/home/link_device_sheet.dart';
import 'package:common/family/widget/profile/profile_utils.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class DeviceSection extends StatefulWidget {
  final DeviceTag tag;

  const DeviceSection({Key? key, required this.tag}) : super(key: key);

  @override
  State<DeviceSection> createState() => DeviceSectionState();
}

class DeviceSectionState extends State<DeviceSection>
    with Logging, Disposables {
  late final _family = DI.get<FamilyActor>();
  late final _device = DI.get<DeviceActor>();
  late final _selectedFilters = DI.get<SelectedFilters>();
  late final _selectedDevice = DI.get<SelectedDeviceTag>();
  late final _custom = DI.get<CustomlistActor>();

  late FamilyDevice device;

  bool built = false;

  @override
  void initState() {
    super.initState();
    disposeLater(_family.devices.onChange.listen(rebuild));
    disposeLater(_selectedFilters.onChange.listen(rebuild));

    _selectedDevice.change(Markers.ui, widget.tag);
  }

  @override
  rebuild(dynamic it) {
    if (!built) return;
    super.rebuild(it);
  }

  @override
  void dispose() {
    _selectedDevice.change(Markers.ui, null);
    disposeAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    built = true;
    device = _family.devices.now.getDevice(widget.tag);
    _custom.setProfileId(device.profile.profileId, Markers.ui);

    return ListView(
      primary: true,
      children: [
        SizedBox(height: getTopPadding(context)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text("family device label statistics".i18n.capitalize(),
              style: const TextStyle(fontWeight: FontWeight.w500)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text("family device brief statistics".i18n,
              style: TextStyle(color: context.theme.textSecondary)),
        ),
        SizedBox(
          //width: width > 600 ? 600 : width,
          width: 600,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: MiniCard(
              onTap: () {
                Navigation.open(Paths.deviceStats, arguments: device);
              },
              child: IgnorePointer(
                ignoring: true,
                child: Column(
                  children: [
                    MiniCardHeader(
                      text: "activity section header".i18n,
                      icon: CupertinoIcons.chart_bar,
                      color: const Color(0xff33c75a),
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text("family device label settings".i18n.capitalize(),
              style: const TextStyle(fontWeight: FontWeight.w500)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text("family device brief settings alt".i18n,
              style: TextStyle(color: context.theme.textSecondary)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: CommonCard(
            child: Column(
              children: [
                Column(
                  children: [
                    CommonItem(
                      onTap: () {
                        showRenameDialog(context, "device", device.device.alias,
                            onConfirm: (name) {
                          _device.renameDevice(
                              device.device, name, Markers.userTap);
                        });
                      },
                      icon: CupertinoIcons.device_phone_portrait,
                      text: "account lease label name".i18n,
                      trailing: Text(device.device.alias,
                          style: TextStyle(color: context.theme.textSecondary)),
                    ),
                    CommonItem(
                      onTap: () {
                        showSelectProfileDialog(context, device: device.device);
                      },
                      icon: CupertinoIcons.person_crop_circle,
                      text: "family stats label profile".i18n,
                      trailing: Row(
                        children: [
                          Icon(getProfileIcon(device.profile.template),
                              color: getProfileColor(device.profile.template),
                              size: 18),
                          const SizedBox(width: 4),
                          Text(device.profile.displayAlias.i18n,
                              style: TextStyle(
                                color: getProfileColor(device.profile.template),
                              )),
                        ],
                      ),
                    ),
                    CommonItem(
                      onTap: () {
                        Navigation.open(Paths.deviceFilters, arguments: device);
                      },
                      icon: CupertinoIcons.shield,
                      text: "family stats label blocklists alt".i18n,
                      trailing: Text(
                          "family stats label blocklists count".i18n.withParams(
                              _selectedFilters.present
                                      ?.map((e) => e.options.length)
                                      .sum() ??
                                  0),
                          style: TextStyle(
                            color: context.theme.textSecondary,
                          )),
                    ),
                    const SizedBox(height: 8),
                    const CommonDivider(indent: 0),
                    CommonItem(
                      onTap: () {},
                      icon: CupertinoIcons.time,
                      text: "family stats label pause".i18n,
                      chevron: false,
                      trailing: CupertinoSwitch(
                        activeColor: context.theme.accent,
                        value: device.device.mode == JsonDeviceMode.off,
                        onChanged: (bool? value) {
                          log(Markers.userTap).i(
                              "changing pause device ${device.device.deviceTag}");
                          _device.pauseDevice(
                              device.device, value ?? false, Markers.userTap);
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
                  child: Text("family device action link".i18n,
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
                      log(Markers.userTap).trace("deleteDevice", (m) async {
                        await _family.deleteDevice(device.device, m);
                      });
                    });
                  },
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text("family device action delete".i18n,
                      style: const TextStyle(
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
