import 'package:carousel_slider/carousel_slider.dart';
import 'package:common/common/model.dart';
import 'package:common/common/widget/minicard/minicard.dart';
import 'package:common/common/widget/theme.dart';
import 'package:common/common/widget/touch.dart';
import 'package:common/dragon/family/devices.dart';
import 'package:common/dragon/family/family.dart';
import 'package:common/dragon/widget/dialog.dart';
import 'package:common/dragon/widget/home/device.dart';
import 'package:common/dragon/widget/home/link_device_sheet.dart';
import 'package:common/util/di.dart';
import 'package:common/util/trace.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

class Devices extends StatefulWidget {
  final FamilyDevices devices;

  const Devices({super.key, required this.devices});

  @override
  DevicesState createState() => DevicesState();
}

class DevicesState extends State<Devices>
    with TickerProviderStateMixin, Traceable, TraceOrigin {
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
  }

  @override
  void didUpdateWidget(Devices oldWidget) {
    super.didUpdateWidget(oldWidget);
    setState(() {});
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final devices = _getDevices(context);

    if (devices.length <= 10) {
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
    //if (widget.devices.) return [];
    return widget.devices.entries
        //.filter((e) => !e.thisDevice)
        //.reversed
        .map((e) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: _wrapInDismissible(
              context,
              e,
              HomeDevice(
                  device: e,
                  color: e.thisDevice
                      ? context.theme.accent
                      : const Color(0xff3c8cff)),
            )))
        .toList();
  }

  Widget _wrapInDismissible(
      BuildContext context, FamilyDevice d, Widget child) {
    return Slidable(
      key: Key(d.device.alias),
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.3,
        children: [
          SlidableAction(
            onPressed: (c) =>
                showSelectProfileDialog(context, device: d.device),
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
            builder: (context) => LinkDeviceSheet(),
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
            builder: (context) => LinkDeviceSheet(),
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
