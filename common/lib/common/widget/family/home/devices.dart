import 'package:carousel_slider/carousel_slider.dart';
import 'package:common/common/widget/family/home/profiles_sheet.dart';
import 'package:common/mock/widget/common_clickable.dart';
import 'package:common/mock/widget/common_divider.dart';
import 'package:common/service/I18nService.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:vistraced/via.dart';

import '../../../../family/family.dart';
import '../../../../mock/widget/add_profile_sheet.dart';
import '../../../../mock/widget/profile_button.dart';
import '../../../../util/di.dart';
import '../../../widget.dart';
import '../../../../family/devices.dart';
import '../../../../util/trace.dart';
import '../smart_header/smart_header_button.dart';
import 'add_device_sheet.dart';
import 'device.dart';

part 'devices.g.dart';

class Devices extends StatefulWidget {
  const Devices({super.key});

  @override
  DevicesState createState() => _$DevicesState();
}

@Injected(onlyVia: true, immediate: true)
class DevicesState extends State<Devices>
    with ViaTools<Devices>, TickerProviderStateMixin, Traceable, TraceOrigin {
  late final _devices = Via.as<FamilyDevices>()..also(rebuild);
  late final _family = dep<FamilyStore>();

  late final AnimationController _ctrl = AnimationController(
    duration: const Duration(seconds: 1),
    vsync: this,
  );

  final CarouselController _carouselCtrl = CarouselController();

  @override
  void initState() {
    super.initState();
    _ctrl.forward();
    _devices.fetch(notify: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final devices = _getDevices(context);

    if (devices.length <= 2) {
      return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[] +
              devices +
              [
                _buildAddDeviceButton2(context),
              ] // +
          //devices,
          );
    }

    // Group devices in pairs and allow vertical carousel scrolling
    final d = devices.reversed.toList();
    final pairs = Iterable.generate((d.length / 2).ceil(), (index) => index * 2)
        .map((i) =>
            _pairWidget(d.sublist(i, i + 2 >= d.length ? d.length : i + 2)))
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
          child: Row(
            children: [
              _buildAddDeviceButton(context),
              Spacer(),
              Touch(
                  onTap: () {
                    _carouselCtrl.nextPage();
                  },
                  decorationBuilder: (value) {
                    return BoxDecoration(
                      color: context.theme.bgMiniCard.withOpacity(value),
                      borderRadius: BorderRadius.circular(4),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(
                      CupertinoIcons.chevron_up,
                      size: 18,
                      color: Colors.white,
                    ),
                  )),
              Touch(
                  onTap: () {
                    _carouselCtrl.previousPage();
                  },
                  decorationBuilder: (value) {
                    return BoxDecoration(
                      color: context.theme.bgMiniCard.withOpacity(value),
                      borderRadius: BorderRadius.circular(4),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(
                      CupertinoIcons.chevron_down,
                      size: 18,
                      color: Colors.white,
                    ),
                  )),
            ],
          ),
        ),
        CarouselSlider(
            items: d.sublist(1),
            carouselController: _carouselCtrl,
            options: CarouselOptions(
              height: 186,
              //aspectRatio: 16 / 9,
              viewportFraction: 1.0,
              initialPage: d.length - 1 - 1,
              enableInfiniteScroll: true,
              reverse: true,
              autoPlay: true,
              autoPlayInterval: const Duration(seconds: 10),
              enlargeCenterPage: false,
              scrollDirection: Axis.vertical,
            )),
        d.first,
      ],
    );
  }

  Widget _pairWidget(List<Widget> widgets) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: widgets.reversed.toList(),
    );
  }

  List<Widget> _getDevices(BuildContext context) {
    if (_devices.dirty) return [];
    return _devices.now.entries
        //.filter((e) => !e.thisDevice)
        //.reversed
        .map((e) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: _wrapInDismissible(
              context,
              e.thisDevice,
              e.deviceName,
              e.deviceDisplayName,
              HomeDevice(
                  device: e,
                  color: e.thisDevice
                      ? context.theme.accent
                      : const Color(0xff3c8cff)),
            )))
        .toList();
  }

  Widget _wrapInDismissible(BuildContext context, bool thisDevice,
      String deviceName, String displayName, Widget child) {
    return Slidable(
      key: Key(deviceName),
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.3,
        children: [
          SlidableAction(
            onPressed: (c) =>
                showSelectProfileDialog(context, deviceName: displayName),
            backgroundColor: context.theme.textPrimary.withOpacity(0.15),
            foregroundColor: Colors.white,
            icon: CupertinoIcons.profile_circled,
            label: "Profile",
            borderRadius: const BorderRadius.all(Radius.circular(8)),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildAddDeviceButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
      child: Touch(
        onTap: () {
          showCupertinoModalBottomSheet(
            context: context,
            duration: const Duration(milliseconds: 300),
            backgroundColor: context.theme.bgColorCard,
            builder: (context) => AddDeviceSheet(),
          );
        },
        decorationBuilder: (value) {
          return BoxDecoration(
            color: context.theme.bgMiniCard.withOpacity(value),
            borderRadius: BorderRadius.circular(4),
          );
        },
        child: const Padding(
          padding: EdgeInsets.all(4.0),
          child: Icon(
            CupertinoIcons.plus_circle,
            size: 32,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildAddDeviceButton2(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: MiniCard(
        onTap: () {
          showCupertinoModalBottomSheet(
            context: context,
            duration: const Duration(milliseconds: 300),
            backgroundColor: context.theme.bgColorCard,
            builder: (context) => AddDeviceSheet(),
          );
        },
        color: context.theme.accent,
        child: SizedBox(
          height: 32,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.plus_circle,
                  size: 28,
                  color: Colors.white,
                ),
                SizedBox(width: 8),
                Text(
                  "Add a device",
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void showSelectProfileDialog(BuildContext context,
    {required String deviceName}) {
  showDefaultDialog(
    context,
    title: Text("Select profile"),
    content: (context) => Column(
        children: [
              Text("Choose a profile to use for $deviceName."),
              SizedBox(height: 32),
            ] +
            ["Parent", "Child", "Custom 1"]
                .map((it) => _buildProfileItem(context, it))
                .flatten()
                .toList() +
            [
              SizedBox(height: 40),
              CommonClickable(
                onTap: () {
                  Navigator.of(context).pop();
                  showCupertinoModalBottomSheet(
                    context: context,
                    duration: const Duration(milliseconds: 300),
                    backgroundColor: context.theme.bgColorCard,
                    builder: (context) => AddProfileSheet(),
                  );
                },
                tapBgColor: context.theme.divider,
                tapBorderRadius: BorderRadius.circular(24),
                padding: EdgeInsets.zero,
                child: Container(
                  decoration: BoxDecoration(
                    color: context.theme.divider.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Icon(
                      CupertinoIcons.plus,
                      size: 16,
                      color: context.theme.textPrimary,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 4),
              Text("Add new profile", style: TextStyle(fontSize: 12)),
            ]),
    actions: (context) => [],
  );
}

List<Widget> _buildProfileItem(BuildContext context, String name) {
  return [
    Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: ProfileButton(
        onTap: () => {Navigator.of(context).pop()},
        icon: name == "Parent"
            ? CupertinoIcons.person_2_alt
            : (name == "Child"
                ? CupertinoIcons.person_solid
                : CupertinoIcons.person_crop_circle),
        iconColor: name == "Parent"
            ? Colors.blue
            : (name == "Child" ? Colors.green : Colors.pink),
        name: name,
        trailing: CommonClickable(
          onTap: () {
            showRenameDialog(context, "profile", name);
          },
          child: Icon(
            CupertinoIcons.pencil,
            size: 16,
            color: context.theme.textSecondary,
          ),
          padding: EdgeInsets.all(16),
        ),
        tapBgColor: context.theme.divider.withOpacity(0.1),
        padding: const EdgeInsets.only(left: 12),
      ),
    ),
  ];
}
