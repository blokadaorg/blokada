import 'package:common/service/I18nService.dart';
import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart';

import '../../../family/family.dart';
import '../../../family/model.dart';
import '../../../util/di.dart';
import '../../../util/trace.dart';
import '../../theme.dart';
import 'device.dart';

class Devices extends StatefulWidget {
  const Devices({super.key});

  @override
  DevicesState createState() => DevicesState();
}

class DevicesState extends State<Devices>
    with TickerProviderStateMixin, Traceable, TraceOrigin {
  late final _family = dep<FamilyStore>();

  late List<FamilyDevice> _devices;
  late int _counter;

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
        _counter = _family.devicesChanges;
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
    return Column(children: devices);
  }

  List<Widget> _getDevices() {
    final theme = Theme.of(context).extension<BlokadaTheme>()!;
    return _devices.reversed
        .map((e) => Padding(
              padding: const EdgeInsets.all(8.0),
              child: (e.thisDevice)
                  ? HomeDevice(device: e, color: theme.family)
                  : _wrapInDismissible(
                      e.deviceName, HomeDevice(device: e, color: Colors.blue)),
            ))
        .toList();
  }

  Widget _wrapInDismissible(String deviceName, Widget child) {
    return Dismissible(
      key: Key(deviceName),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.red,
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text("universal action delete".i18n,
              style: const TextStyle(color: Colors.white)),
        ),
      ),
      dismissThresholds: const {
        DismissDirection.endToStart: 0.4,
      },
      onDismissed: (direction) {
        traceAs("tappedDeleteDevice", (trace) async {
          await _family.deleteDevice(trace, deviceName);
        });
      },
      child: child,
    );
  }
}
