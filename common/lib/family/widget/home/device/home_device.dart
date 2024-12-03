import 'package:common/common/navigation.dart';
import 'package:common/common/widget/minicard/chart.dart';
import 'package:common/common/widget/minicard/minicard.dart';
import 'package:common/core/core.dart';
import 'package:common/family/module/family/family.dart';
import 'package:common/family/module/profile/profile.dart';
import 'package:common/family/widget/home/device/home_device_header.dart';
import 'package:flutter/material.dart';

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
  State<StatefulWidget> createState() => HomeDeviceState();
}

class HomeDeviceState extends State<HomeDevice> with TickerProviderStateMixin {
  late final _profiles = Core.get<ProfileActor>();

  _onTap() async {
    _profiles.selectProfile(Markers.userTap, widget.device.profile);

    Navigation.open(Paths.device, arguments: widget.device);
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
              text: widget.device.displayName,
              iconName: widget.device.device.alias,
              color: widget.color,
              chevronText: widget.device.profile.displayAlias.i18n,
              chevronIcon: Icons.chevron_right,
            ),
            const SizedBox(height: 12),
            ClipRect(
              child: IgnorePointer(
                ignoring: true,
                child: MiniCardChart(
                    stats: widget.device.stats, color: widget.color),
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
}
