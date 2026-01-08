import 'dart:async';

import 'package:collection/collection.dart';
import 'package:common/src/features/lock/domain/lock.dart';
import 'package:common/src/features/modal/domain/modal.dart';
import 'package:common/src/features/payment/domain/payment.dart';
import 'package:common/src/shared/ui/top_bar.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/app_variants/family/module/auth/auth.dart';
import 'package:common/src/app_variants/family/module/device_v3/device.dart';
import 'package:common/src/app_variants/family/module/perm/perm.dart';
import 'package:common/src/app_variants/family/module/profile/profile.dart';
import 'package:common/src/app_variants/family/module/stats/stats.dart';
import 'package:common/src/app_variants/family/widget/add_profile_sheet.dart';
import 'package:common/src/app_variants/family/widget/home/link_device_sheet.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/platform/perm/perm.dart';
import 'package:common/src/platform/stage/channel.pg.dart';
import 'package:common/src/platform/stage/stage.dart';
import 'package:dartx/dartx.dart';

part 'actor.dart';
part 'command.dart';
part 'devices.dart';
part 'link_actor.dart';
part 'model.dart';
part 'value.dart';

class FamilyModule with Module {
  @override
  onCreateModule() async {
    await register(FamilyPhaseValue());
    await register(FamilyDevicesValue());
    await register(FamilyActor());
    await register(FamilyLinkedMode());
    await register(LinkActor());
    await register(FamilyCommand());
    await register(FamilySheetActor());
  }
}

class FamilySheetActor with Actor {
  late final _modal = Core.get<CurrentModalValue>();
  late final _modalWidget = Core.get<CurrentModalWidgetValue>();

  @override
  onCreate(Marker m) async {
    // Provide the widget factory for the modal this module handles
    _modal.onChange.listen((it) {
      if (it.now == Modal.familyLinkDevice) {
        _modalWidget.change(it.m, (context) => const LinkDeviceSheet());
      } else if (it.now == Modal.familyAddProfile) {
        _modalWidget.change(it.m, (context) => const AddProfileSheet());
      }
    });
  }
}
