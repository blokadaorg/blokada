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
