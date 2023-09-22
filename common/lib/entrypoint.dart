import 'account/account.dart';
import 'account/payment/payment.dart';
import 'account/refresh/refresh.dart';
import 'app/app.dart';
import 'app/start/start.dart';
import 'command/channel.pg.dart';
import 'command/command.dart';
import 'custom/custom.dart';
import 'deck/deck.dart';
import 'device/device.dart';
import 'env/env.dart';
import 'http/http.dart';
import 'journal/journal.dart';
import 'lock/lock.dart';
import 'notification/notification.dart';
import 'onboard/onboard.dart';
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
import 'ui/home/home.dart';
import 'util/config.dart';
import 'util/di.dart';
import 'util/trace.dart';
import 'tracer/tracer.dart';

class Entrypoint with Dependable, TraceOrigin, Traceable {
  late final _appStart = dep<AppStartStore>();

  @override
  attach(Act act) {
    cfg.act = act;
    Tracer().attach(act);
    DefaultTimer().attach(act);

    PlatformPersistence(isSecure: false).attach(act);
    final secure = PlatformPersistence(isSecure: true);
    depend<SecurePersistenceService>(secure);

    if (act.hasToys()) {
      RepeatingHttpService(
        DebugHttpService(PlatformHttpService()),
        maxRetries: cfg.httpMaxRetries,
        waitTime: cfg.httpRetryDelay,
      ).attach(act);
    } else {
      RepeatingHttpService(
        PlatformHttpService(),
        maxRetries: cfg.httpMaxRetries,
        waitTime: cfg.httpRetryDelay,
      ).attach(act);
    }

    // The stores. Order is important
    EnvStore().attach(act);
    StageStore().attach(act);
    LockStore().attach(act);
    OnboardStore().attach(act);
    AccountStore().attach(act);
    NotificationStore().attach(act);
    AccountPaymentStore().attach(act);
    AccountRefreshStore().attach(act);
    DeviceStore().attach(act);
    AppStore().attach(act);
    AppStartStore().attach(act);
    CustomStore().attach(act);
    DeckStore().attach(act);
    JournalStore().attach(act);
    PlusStore().attach(act);
    PlusKeypairStore().attach(act);
    PlusGatewayStore().attach(act);
    PlusLeaseStore().attach(act);
    PlusVpnStore().attach(act);
    PermStore().attach(act);
    StatsStore().attach(act);
    StatsRefreshStore().attach(act);
    HomeStore().attach(act);
    RateStore().attach(act);
    CommandStore().attach(act);

    depend<Entrypoint>(this);
  }

  Future<void> onStartApp() async {
    await traceAs("onStartApp", (trace) async {
      await _appStart.startApp(trace);
    });
  }
}
