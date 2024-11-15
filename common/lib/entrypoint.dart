import 'package:common/dragon/dragon_deps.dart';
import 'package:common/dragon/filter/filter_legacy.dart';
import 'package:common/dragon/widget/common/top_bar.dart';
import 'package:common/dragon/widget/v6/home/home.dart';
import 'package:common/logger/logger.dart';
import 'package:common/perm/dnscheck.dart';

import 'account/account.dart';
import 'account/payment/payment.dart';
import 'account/refresh/refresh.dart';
import 'app/app.dart';
import 'app/start/start.dart';
import 'command/command.dart';
import 'custom/custom.dart';
import 'device/device.dart';
import 'dragon/family/family.dart';
import 'env/env.dart';
import 'http/http.dart';
import 'journal/journal.dart';
import 'link/link.dart';
import 'lock/lock.dart';
import 'notification/notification.dart';
import 'perm/perm.dart';
import 'persistence/persistence.dart';
import 'plus/gateway/gateway.dart';
import 'plus/keypair/keypair.dart';
import 'plus/lease/lease.dart';
import 'plus/plus.dart';
import 'plus/vpn/vpn.dart';
import 'rate/rate.dart';
import 'stage/stage.dart';
import 'stats/refresh/refresh.dart';
import 'stats/stats.dart';
import 'timer/timer.dart';
import 'util/config.dart';
import 'util/di.dart';

class Entrypoint with Dependable, Logging {
  late final _appStart = dep<AppStartStore>();

  @override
  attach(Act act) {
    cfg.act = act;

    DefaultTimer().attachAndSaveAct(act);
    LoggerCommands().attachAndSaveAct(act);

    // Newer deps of the new code - temporary, this will eventually
    // replace the legacy code. Hopefully, you know how it goes :D
    final dragonDeps = DragonDeps().register(act);

    PlatformPersistence(isSecure: false).attachAndSaveAct(act);
    final secure = PlatformPersistence(isSecure: true);
    depend<SecurePersistenceService>(secure);

    if (act.hasToys()) {
      RepeatingHttpService(
        DebugHttpService(PlatformHttpService()),
        maxRetries: cfg.httpMaxRetries,
        waitTime: cfg.httpRetryDelay,
      ).attachAndSaveAct(act);
    } else {
      RepeatingHttpService(
        PlatformHttpService(),
        maxRetries: cfg.httpMaxRetries,
        waitTime: cfg.httpRetryDelay,
      ).attachAndSaveAct(act);
    }

    // The stores. Order is important
    EnvStore().attachAndSaveAct(act);
    StageStore().attachAndSaveAct(act);
    AccountStore().attachAndSaveAct(act);
    NotificationStore().attachAndSaveAct(act);
    AccountPaymentStore().attachAndSaveAct(act);
    AccountRefreshStore().attachAndSaveAct(act);
    DeviceStore().attachAndSaveAct(act);

    // Compatibility layer for v6 (temporary
    if (!act.isFamily()) {
      depend<FilterLegacy>(FilterLegacy(act));
    }

    AppStore().attachAndSaveAct(act);
    AppStartStore().attachAndSaveAct(act);
    PrivateDnsCheck().attachAndSaveAct(act);
    PermStore().attachAndSaveAct(act);
    LockStore().attachAndSaveAct(act);
    CustomStore().attachAndSaveAct(act);

    if (!act.isFamily()) {
      JournalStore().attachAndSaveAct(act);
      PlusStore().attachAndSaveAct(act);
      PlusKeypairStore().attachAndSaveAct(act);
      PlusGatewayStore().attachAndSaveAct(act);
      PlusLeaseStore().attachAndSaveAct(act);
      PlusVpnStore().attachAndSaveAct(act);
      HomeStore().attachAndSaveAct(act);
    }

    StatsStore().attachAndSaveAct(act);
    StatsRefreshStore().attachAndSaveAct(act);

    if (act.isFamily()) {
      FamilyStore().attachAndSaveAct(act);
    }

    RateStore().attachAndSaveAct(act);
    CommandStore().attachAndSaveAct(act);
    LinkStore().attachAndSaveAct(act);

    depend<TopBarController>(TopBarController());
    depend<Entrypoint>(this);

    dragonDeps.load(act);
  }

  Future<void> onStartApp() async {
    await _appStart.startApp(Markers.start);
  }
}
