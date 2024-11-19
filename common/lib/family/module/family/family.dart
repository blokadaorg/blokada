import 'dart:async';

import 'package:collection/collection.dart';
import 'package:common/common/model/model.dart';
import 'package:common/core/core.dart';
import 'package:common/family/module/auth/auth.dart';
import 'package:common/family/module/device_v3/device.dart';
import 'package:common/family/module/perm/perm.dart';
import 'package:common/family/module/profile/profile.dart';
import 'package:common/family/module/stats/stats.dart';
import 'package:common/family/widget/home/private_dns/private_dns_sheet_android.dart';
import 'package:common/family/widget/home/private_dns/private_dns_sheet_ios.dart';
import 'package:common/lock/lock.dart';
import 'package:common/platform/account/account.dart';
import 'package:common/platform/perm/perm.dart';
import 'package:common/platform/stage/channel.pg.dart';
import 'package:common/platform/stage/stage.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';

part 'actor.dart';
part 'command.dart';
part 'devices.dart';
part 'link_actor.dart';
part 'value.dart';

class FamilyModule with Module {
  @override
  onCreateModule(Act act) async {
    await register(FamilyPhaseValue());
    await register(FamilyDevicesValue());
    await register(FamilyActor());
    await register(FamilyLinkedMode());
    await register(LinkActor());
    await register(FamilyCommand());

    if (act.platform == PlatformType.iOS) {
      await register<StatefulWidget>(const PrivateDnsSheetIos(),
          tag: "privateDnsSheet");
    } else {
      await register<StatefulWidget>(const PrivateDnsSheetAndroid(),
          tag: "privateDnsSheet");
    }
  }
}
