import 'package:common/src/features/api/domain/api.dart';
import 'package:common/src/features/config/domain/config.dart';
import 'package:common/src/features/env/domain/env.dart';
import 'package:common/src/features/link/domain/link.dart';
import 'package:common/src/features/notification/domain/notification.dart';
import 'package:common/src/features/rate/domain/rate.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/platform/common/channel.pg.dart';

part 'channel.dart';

class PlatformCommonModule with Logging, Module {
  @override
  onCreateModule() async {
    CommonChannel channel;

    // Mocked scenario uses the real platform channel so HTTP, notifications,
    // rate/env/link/config calls hit iOS code (which then talks to the real
    // backend at api.blocka.net / family.api.blocka.net). NoOpCommonChannel
    // is only for unit tests where the platform host is unavailable.
    if (Core.act.isProd || Core.act.isMocked) {
      channel = PlatformCommonChannel();
    } else {
      channel = NoOpCommonChannel();
    }

    await register<RateChannel>(channel);
    await register<EnvChannel>(channel);
    await register<LinkChannel>(channel);
    await register<HttpChannel>(channel);
    await register<NotificationChannel>(channel);
    await register<ConfigChannel>(channel);
  }
}
