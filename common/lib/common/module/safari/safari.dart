import 'package:common/common/module/api/api.dart';
import 'package:common/common/module/modal/modal.dart';
import 'package:common/common/module/onboard/onboard.dart';
import 'package:common/common/module/payment/payment.dart';
import 'package:common/common/widget/safari/safari_content_onboard_sheet.dart';
import 'package:common/common/widget/safari/safari_youtube_onboard_sheet.dart';
import 'package:common/core/core.dart';
import 'package:common/family/module/device_v3/device.dart';
import 'package:common/platform/account/account.dart';
import 'package:common/platform/app/app.dart';
import 'package:common/platform/app/channel.pg.dart';
import 'package:common/platform/perm/perm.dart';
import 'package:common/util/mobx.dart';

part 'content_actor.dart';
part 'value.dart';
part 'youtube_actor.dart';

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
    await register(SafariYoutubeActor());
    await register(SafariContentActor());
  }
}

@PlatformProvided()
mixin SafariChannel {
  Future<bool> doGetStateOfContentFilter();
  Future<void> doUpdateContentFilterRules(bool filtering);
  Future<void> doOpenPermsFlowForYoutube();
  Future<void> doOpenPermsFlowForContentFilter();
}
