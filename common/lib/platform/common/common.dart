import 'package:common/common/module/api/api.dart';
import 'package:common/common/module/env/env.dart';
import 'package:common/common/module/link/link.dart';
import 'package:common/common/module/notification/notification.dart';
import 'package:common/common/module/rate/rate.dart';
import 'package:common/core/core.dart';
import 'package:common/platform/common/channel.pg.dart';

part 'channel.dart';

class PlatformCommonModule with Logging, Module {
  @override
  onCreateModule() async {
    CommonChannel channel;

    if (Core.act.isProd) {
      channel = PlatformCommonChannel();
    } else {
      channel = NoOpCommonChannel();
    }

    await register<RateChannel>(channel);
    await register<EnvChannel>(channel);
    await register<LinkChannel>(channel);
    await register<HttpChannel>(channel);
    await register<NotificationChannel>(channel);
  }
}
