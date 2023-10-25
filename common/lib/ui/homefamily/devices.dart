import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart';

import '../../family/famdevice/famdevice.dart';
import '../../util/di.dart';
import '../../util/trace.dart';
import '../anim/sliding.dart';
import '../theme.dart';
import 'device.dart';

class Devices extends StatefulWidget {
  const Devices({super.key});

  @override
  DevicesState createState() => DevicesState();
}

class DevicesState extends State<Devices>
    with TickerProviderStateMixin, Traceable, TraceOrigin {
  late final _famDevice = dep<FamilyDeviceStore>();

  List<FamilyDevice> devices = [];
  var _ch = 0;

  late final AnimationController _ctrl = AnimationController(
    duration: const Duration(seconds: 1),
    vsync: this,
  );

  @override
  void initState() {
    super.initState();
    _ctrl.forward();

    autorun((_) {
      setState(() {
        _ch = _famDevice.devicesChanges;
        devices = _famDevice.devices;
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
    return Column(children: devices);
  }

  List<Widget> _getDevices() {
    final theme = Theme.of(context).extension<BlokadaTheme>()!;
    return devices.reversed
        .map((e) => Sliding(
              controller: _ctrl,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: HomeDevice(
                  onLongPress: () {
                    traceAs("tappedDeleteDevice", (trace) async {
                      await _famDevice.deleteDevice(trace, e.deviceName);
                    });
                  },
                  deviceName: e.deviceDisplayName,
                  device: e,
                  thisDevice: e.thisDevice,
                  color: e.thisDevice ? theme.family : Colors.blue,
                ),
              ),
            ))
        .toList();
  }
}
