import 'package:common/common/widget/family/home/header.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:vistraced/via.dart';

import '../../../model.dart';
import '../../../widget.dart';
import '../../../../util/trace.dart';
import '../../minicard/chart.dart';
import '../device/device_screen.dart';
import 'guest_sheet.dart';

part 'device.g.dart';

class HomeDevice extends StatefulWidget {
  final void Function()? onLongPress;
  final FamilyDevice device;
  final Color color;

  const HomeDevice({
    Key? key,
    this.onLongPress,
    required this.device,
    required this.color,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _$HomeDeviceState();
}

@Injected(onlyVia: true, immediate: true)
class HomeDeviceState extends State<HomeDevice>
    with TickerProviderStateMixin, TraceOrigin {
  @MatcherSpec(of: "stage")
  late final _route = Via.as<String>();

  @MatcherSpec(of: "family")
  late final _selectedDevice = Via.as<String>();

  _onTap() async {
    if (widget.device.deviceName.isEmpty) return;
    await _selectedDevice.set(widget.device.deviceName);

    Navigator.pushNamed(
      context,
      "/device",
      arguments: widget.device,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: widget.onLongPress,
      child: MiniCard(
        onTap: _onTap,
        // outlined: widget.thisDevice,
        outlined: false,
        child: Column(
          children: [
            DeviceCardHeader(
              text: widget.device.deviceDisplayName,
              iconName: widget.device.deviceName,
              color: widget.color,
              chevronText: widget.device.thisDevice ? "Parent" : "Child",
              chevronIcon: Icons.chevron_right,
            ),
            const SizedBox(height: 12),
            ClipRect(
              child: IgnorePointer(
                ignoring: true,
                child:
                    MiniCardChart(device: widget.device, color: widget.color),
              ),
            ),
            // SizedBox(height: 12),
            // (widget.device.thisDevice)
            //     ? Column(
            //         children: [
            //           // Divider(
            //           //   color: context.theme.divider,
            //           //   height: 1,
            //           //   indent: 4,
            //           //   endIndent: 4,
            //           //   thickness: 0.4,
            //           // ),
            //           Row(
            //             mainAxisAlignment: MainAxisAlignment.end,
            //             children: [
            //               MiniCard(
            //                   // color: context.theme.bgColor,
            //                   //onTap: _handleGuestTap,
            //                   child: SizedBox(
            //                 height: 24,
            //                 width: 24,
            //                 // child: Icon(CupertinoIcons.power),
            //                 child: Icon(CupertinoIcons.power,
            //                     color: context.theme.textSecondary),
            //               )),
            //               SizedBox(width: 8),
            //               MiniCard(
            //                   // color: context.theme.bgColor,
            //                   onTap: _handleGuestTap,
            //                   child: SizedBox(
            //                     height: 24,
            //                     width: 24,
            //                     // child: Icon(CupertinoIcons.lock),
            //                     child: Icon(CupertinoIcons.lock_open,
            //                         color: context.theme.textSecondary),
            //                   )),
            //               //SizedBox(width: 8),
            //               Spacer(),
            //               // MiniCard(
            //               //     //color: context.theme.bgColor,
            //               //     //onTap: _handleGuestTap,
            //               //     child: SizedBox(
            //               //   height: 24,
            //               //   width: 24,
            //               //   // child: Icon(CupertinoIcons.lock_shield_fill),
            //               //   child: Icon(CupertinoIcons.ellipsis,
            //               //       color: context.theme.textSecondary),
            //               // )),
            //             ],
            //           ),
            //         ],
            //       )
            //     : Container(),
          ],
          //footer: "home status detail active".i18n.replaceAll("*", ""),
        ),
      ),
    );
  }

  _handleGuestTap() {
    showCupertinoModalBottomSheet(
      context: context,
      backgroundColor: context.theme.bgColorCard,
      duration: const Duration(milliseconds: 300),
      builder: (context) => GuestSheet(),
    );
  }
}
