import 'package:carousel_slider/carousel_slider.dart';
import 'package:common/service/I18nService.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:mobx/mobx.dart';

import '../../../family/devices.dart';
import '../../../family/family.dart';
import '../../../util/di.dart';
import '../../../util/trace.dart';
import '../../theme.dart';
import '../../touch.dart';
import 'device.dart';

class Devices extends StatefulWidget {
  const Devices({super.key});

  @override
  DevicesState createState() => DevicesState();
}

class DevicesState extends State<Devices>
    with TickerProviderStateMixin, Traceable, TraceOrigin {
  late final _family = dep<FamilyStore>();

  late FamilyDevices _devices;

  late final AnimationController _ctrl = AnimationController(
    duration: const Duration(seconds: 1),
    vsync: this,
  );

  final CarouselController _carouselCtrl = CarouselController();

  @override
  void initState() {
    super.initState();
    _ctrl.forward();

    autorun((_) {
      setState(() {
        _devices = _family.devices;
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
    _ctrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<BlokadaTheme>()!;

    final devices = _getDevices();

    if (devices.length <= 2) {
      return Column(children: devices);
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
              Touch(
                  onTap: () {
                    _carouselCtrl.nextPage();
                  },
                  decorationBuilder: (value) {
                    return BoxDecoration(
                      color: theme.bgMiniCard.withOpacity(value),
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
                      color: theme.bgMiniCard.withOpacity(value),
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
              height: 176,
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

  List<Widget> _getDevices() {
    final theme = Theme.of(context).extension<BlokadaTheme>()!;
    return _devices.entries.reversed
        .map((e) => Padding(
            padding: const EdgeInsets.all(8.0),
            child: _wrapInDismissible(
              e.thisDevice,
              e.deviceName,
              HomeDevice(
                  device: e,
                  color: e.thisDevice ? theme.family : const Color(0xff3c8cff)),
            )))
        .toList();
  }

  Widget _wrapInDismissible(bool thisDevice, String deviceName, Widget child) {
    return Slidable(
      key: Key(deviceName),
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.3,
        children: [
          SlidableAction(
            onPressed: (context) => _delete(deviceName),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: thisDevice ? CupertinoIcons.power : CupertinoIcons.delete,
            label: thisDevice
                ? "universal action disable".i18n
                : "universal action delete".i18n,
            borderRadius: const BorderRadius.all(Radius.circular(8)),
          ),
        ],
      ),
      child: child,
    );
  }

  void _delete(String deviceName) {
    traceAs("tappedDeleteDevice", (trace) async {
      await _family.deleteDevice(trace, deviceName);
    });
  }
}
