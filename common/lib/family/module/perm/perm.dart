import 'package:common/core/core.dart';
import 'package:common/family/module/device_v3/device.dart';
import 'package:common/platform/perm/dnscheck.dart';
import 'package:common/platform/stage/channel.pg.dart';
import 'package:common/platform/stage/stage.dart';
import 'package:flutter/material.dart';

part 'actor.dart';
part 'value.dart';

class PermModule with Module {
  @override
  onCreateModule() async {
    await register(DnsPerm());
    await register(PermActor());
  }
}
