import 'package:common/common/widget/top_bar.dart';
import 'package:common/core/core.dart';
import 'package:common/dragon/dragon_deps.dart';
import 'package:common/dragon/filter/filter_legacy.dart';
import 'package:common/platform/logger/logger.dart';
import 'package:common/platform/perm/dnscheck.dart';
import 'package:common/v6/widget/home/home.dart';

import 'dragon/family/family.dart';
import 'lock/lock.dart';
import 'platform/account/account.dart';
import 'platform/account/payment/payment.dart';
import 'platform/account/refresh/refresh.dart';
import 'platform/app/app.dart';
import 'platform/app/start/start.dart';
import 'platform/command/command.dart';
import 'platform/custom/custom.dart';
import 'platform/device/device.dart';
import 'platform/env/env.dart';
import 'platform/http/http.dart';
import 'platform/journal/journal.dart';
import 'platform/link/link.dart';
import 'platform/notification/notification.dart';
import 'platform/perm/perm.dart';
import 'platform/persistence/persistence.dart';
import 'platform/plus/gateway/gateway.dart';
import 'platform/plus/keypair/keypair.dart';
import 'platform/plus/lease/lease.dart';
import 'platform/plus/plus.dart';
import 'platform/plus/vpn/vpn.dart';
import 'platform/rate/rate.dart';
import 'platform/stage/stage.dart';
import 'platform/stats/refresh/refresh.dart';
import 'platform/stats/stats.dart';
import 'timer/timer.dart';

class Entrypoint with Actor, Logging {
  late final _appStart = DI.get<AppStartStore>();

  @override
  onRegister(Act act) {
    cfg.act = act;

    DefaultTimer().register(act);
    LoggerCommands().register(act);

    // Newer deps of the new code - temporary, this will eventually
    // replace the legacy code. Hopefully, you know how it goes :D
    final dragonDeps = DragonDeps().register(act);

    PersistenceActor().register(act);

    if (act.hasToys) {
      RepeatingHttpService(
        DebugHttpService(PlatformHttpService()),
        maxRetries: cfg.httpMaxRetries,
        waitTime: cfg.httpRetryDelay,
      ).register(act);
    } else {
      RepeatingHttpService(
        PlatformHttpService(),
        maxRetries: cfg.httpMaxRetries,
        waitTime: cfg.httpRetryDelay,
      ).register(act);
    }

    // The stores. Order is important
    EnvStore().register(act);
    StageStore().register(act);
    AccountStore().register(act);
    NotificationStore().register(act);
    AccountPaymentStore().register(act);
    AccountRefreshStore().register(act);
    DeviceStore().register(act);

    // Compatibility layer for v6 (temporary
    if (!act.isFamily) {
      DI.register<FilterLegacy>(FilterLegacy(act));
    }

    AppStore().register(act);
    AppStartStore().register(act);
    PrivateDnsCheck().register(act);
    PermStore().register(act);
    LockStore().register(act);
    CustomStore().register(act);

    if (!act.isFamily) {
      JournalStore().register(act);
      PlusStore().register(act);
      PlusKeypairStore().register(act);
      PlusGatewayStore().register(act);
      PlusLeaseStore().register(act);
      PlusVpnStore().register(act);
      HomeStore().register(act);
    }

    StatsStore().register(act);
    StatsRefreshStore().register(act);

    if (act.isFamily) {
      FamilyStore().register(act);
    }

    RateStore().register(act);
    CommandStore().register(act);
    LinkStore().register(act);

    DI.register<TopBarController>(TopBarController());
    DI.register<Entrypoint>(this);

    dragonDeps.load(act);
  }

  Future<void> onStartApp() async {
    await _appStart.startApp(Markers.start);
  }
}
