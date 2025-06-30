import 'package:common/common/module/api/api.dart';
import 'package:common/common/module/modal/modal.dart';
import 'package:common/common/module/onboard/onboard.dart';
import 'package:common/common/module/payment/payment.dart';
import 'package:common/common/widget/safari/safari_youtube_onboard_sheet.dart';
import 'package:common/core/core.dart';
import 'package:common/family/module/device_v3/device.dart';
import 'package:common/family/module/perm/perm.dart';
import 'package:common/platform/account/account.dart';
import 'package:common/platform/app/app.dart';
import 'package:common/platform/app/channel.pg.dart';
import 'package:common/platform/perm/perm.dart';
import 'package:common/platform/stage/stage.dart';
import 'package:common/util/mobx.dart';

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
