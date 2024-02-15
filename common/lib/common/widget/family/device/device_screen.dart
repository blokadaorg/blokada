import 'package:common/common/widget.dart';
import 'package:common/common/widget/family/home/devices.dart';
import 'package:common/mock/widget/common_clickable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vistraced/via.dart';

import '../../../../mock/widget/add_profile_sheet.dart';
import '../../../../mock/widget/common_card.dart';
import '../../../../mock/widget/common_divider.dart';
import '../../../../mock/widget/common_item.dart';
import '../../../../stage/channel.pg.dart';
import '../../../model.dart';
import '../home/top_bar.dart';
import '../stats/radial_segment.dart';

part 'device_screen.g.dart';

class DeviceScreen extends StatefulWidget {
  final FamilyDevice device;

  const DeviceScreen({Key? key, required this.device}) : super(key: key);

  @override
  State<DeviceScreen> createState() => _$DeviceScreenState();
}

@Injected(onlyVia: true, immediate: true)
class DeviceScreenState extends State<DeviceScreen>
    with ViaTools<DeviceScreen> {
  late final _modal = Via.as<StageModal?>()..also(rebuild);

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateTopBar);
  }

  void _updateTopBar() {
    Provider.of<TopBarController>(context, listen: false)
        .updateScrollPos(_scrollController.offset);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateTopBar);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.theme.bgColor,
      body: PrimaryScrollController(
        controller: _scrollController,
        child: Stack(
          children: [
            ListView(
              primary: true,
              padding: EdgeInsets.zero,
              children: [
                SizedBox(height: 100),
                // Column(
                //   children: [
                //     SizedBox(height: 12),
                //     AvatarIconWidget(
                //         name: widget.device.thisDevice
                //             ? null
                //             : widget.device.deviceDisplayName,
                //         color: widget.device.thisDevice
                //             ? context.theme.family
                //             : Color(0xff3c8cff)),
                //     SizedBox(height: 8),
                //     Text(
                //         widget.device.thisDevice
                //             ? widget.device.deviceDisplayName
                //             : widget.device.deviceDisplayName + " device",
                //         style: TextStyle(
                //             fontSize: 28, fontWeight: FontWeight.w700)),
                //     widget.device.thisDevice
                //         ? Container()
                //         : GestureDetector(
                //             onTap: () {
                //               showRenameDialog(
                //                   context, "device", widget.device.deviceName);
                //             },
                //             child: Text("Edit",
                //                 style: TextStyle(color: context.theme.family)),
                //           ),
                //   ],
                // ),
                SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text("STATISTICS",
                      style: TextStyle(fontWeight: FontWeight.w500)),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: MiniCard(
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          "/device/stats",
                          arguments: widget.device,
                        );
                      },
                      child: IgnorePointer(
                        ignoring: true,
                        child: Column(
                          children: [
                            MiniCardHeader(
                              text: "Activity",
                              icon: CupertinoIcons.chart_bar,
                              color: Color(0xff33c75a),
                              chevronIcon: Icons.chevron_right,
                            ),
                            SizedBox(height: 4),
                            RadialSegment(device: widget.device),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text("DEVICE SETTINGS",
                      style: TextStyle(fontWeight: FontWeight.w500)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                      "Edit the blocking profile to apply for this device.",
                      style: TextStyle(color: context.theme.textSecondary)),
                ),
                Container(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: CommonCard(
                      child: Column(
                        children: [
                          Column(
                            children: [
                              CommonItem(
                                onTap: () {
                                  showRenameDialog(context, "device", "Alva");
                                },
                                icon: CupertinoIcons.device_phone_portrait,
                                text: "Name",
                                trailing: Text("Alva",
                                    style: TextStyle(
                                        color: context.theme.textSecondary)),
                              ),
                              CommonItem(
                                onTap: () {
                                  showSelectProfileDialog(context,
                                      deviceName:
                                          widget.device.deviceDisplayName);
                                },
                                icon: CupertinoIcons.person_crop_circle,
                                text: "Blocklist Profile",
                                trailing: Row(
                                  children: [
                                    Icon(
                                        widget.device.thisDevice
                                            ? CupertinoIcons.person_2_alt
                                            : CupertinoIcons.person_solid,
                                        color: widget.device.thisDevice
                                            ? Colors.blue
                                            : Colors.green,
                                        size: 18),
                                    SizedBox(width: 4),
                                    Text(
                                        widget.device.thisDevice
                                            ? "Parent"
                                            : "Child",
                                        style: TextStyle(
                                          color: widget.device.thisDevice
                                              ? Colors.blue
                                              : Colors.green,
                                        )),
                                  ],
                                ),
                              ),
                              CommonItem(
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    "/device/profile",
                                    arguments: widget.device,
                                  );
                                },
                                icon: CupertinoIcons.shield,
                                text: "Blocklists",
                                trailing: Text(
                                    widget.device.thisDevice
                                        ? "2 selected"
                                        : "4 selected",
                                    style: TextStyle(
                                      color: context.theme.textSecondary,
                                    )),
                              ),
                              SizedBox(height: 8),
                              CommonDivider(indent: 0),
                              CommonItem(
                                onTap: () {},
                                icon: CupertinoIcons.time,
                                text: "Pause blocking",
                                chevron: false,
                                trailing: CupertinoSwitch(
                                  activeColor: context.theme.accent,
                                  value: false,
                                  onChanged: (bool? value) {
                                    // setState(() {
                                    //   selected = value!;
                                    // });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                widget.device.thisDevice
                    ? Container()
                    : Container(
                        constraints: const BoxConstraints(maxWidth: 500),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12.0),
                          child: CommonClickable(
                            onTap: () {
                              showConfirmDialog(
                                  context, widget.device.deviceDisplayName);
                            },
                            child: Text("Delete this device",
                                style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500)),
                          ),
                        ),
                      ),
                SizedBox(height: 48),
              ],
            ),
            TopBar(title: widget.device.deviceDisplayName),
          ],
        ),
      ),
      //),
    );
  }
}

void showConfirmDialog(BuildContext context, String name) {
  showDefaultDialog(
    context,
    title: Text("Delete device"),
    content: (context) => Column(
      children: [
        Text(
            "Are you sure you wish to delete $name? The device will be unlinked from your account."),
      ],
    ),
    actions: (context) => [
      TextButton(
        onPressed: () {
          Navigator.of(context).pop();
        },
        child: const Text("Cancel"),
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(0.0),
          ),
        ),
      ),
      TextButton(
        onPressed: () {
          Navigator.of(context).pop();
        },
        child: const Text("Delete", style: TextStyle(color: Colors.red)),
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(0.0),
          ),
        ),
      ),
    ],
  );
}
