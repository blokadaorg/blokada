import 'package:common/src/features/api/domain/api.dart';
import 'package:common/src/features/modal/domain/modal.dart';
import 'package:common/src/features/onboard/domain/onboard.dart';
import 'package:common/src/features/payment/domain/payment.dart';
import 'package:common/src/features/safari/ui/safari_onboard_sheet.dart';
import 'package:common/src/features/safari/ui/safari_onboard_yt_sheet.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/app_variants/family/module/device_v3/device.dart';
import 'package:common/src/platform/account/account.dart';
import 'package:common/src/platform/app/app.dart';
import 'package:common/src/platform/app/channel.pg.dart';
import 'package:common/src/platform/perm/perm.dart';
import 'package:common/src/platform/stage/stage.dart';
import 'package:common/src/util/mobx.dart';

part 'actor.dart';
part 'value.dart';

/// SafariModule handles integration with the Safari browser extensions (iOS only).
///
/// We have two extensions so far:
/// - for YouTube (aka blockaweb) - blocks ads in YouTube videos specifically
/// - content filter for Safari - blocks ads in Safari browser using a basic list
///
/// This module handles state sync, and activating those extensions if possible.

class SafariModule with Module {
  @override
  onCreateModule() async {
    await register(BlockawebAppStatusValue());
    await register(BlockawebPingValue());
    await register(SafariActor());
  }
}

@PlatformProvided()
mixin SafariChannel {
  Future<void> doOpenSafariSetup();
}
