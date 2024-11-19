import 'package:common/common/api/api.dart';
import 'package:common/common/module/account/account.dart';
import 'package:common/common/module/filter/filter.dart';
import 'package:common/common/module/list/list.dart';
import 'package:common/common/module/rate/rate.dart';
import 'package:common/common/module/support/support.dart';
import 'package:common/common/widget/top_bar.dart';
import 'package:common/core/core.dart';
import 'package:common/family/module/auth/auth.dart';
import 'package:common/family/module/customlist_v3/customlist.dart';
import 'package:common/family/module/device_v3/device.dart';
import 'package:common/family/module/family/family.dart';
import 'package:common/family/module/journal/journal.dart';
import 'package:common/family/module/perm/perm.dart';
import 'package:common/family/module/profile/profile.dart';
import 'package:common/family/module/stats/stats.dart';
import 'package:common/lock/lock.dart';
import 'package:common/platform/filter/filter.dart';
import 'package:common/platform/logger/logger.dart';
import 'package:common/platform/perm/dnscheck.dart';
import 'package:common/platform/persistence/persistence.dart';
import 'package:common/v6/widget/home/home.dart';

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

class Modules with Logging {
  late final _appStart = DI.get<AppStartStore>();

  create(Act act) async {
    cfg.act = act;
    this.act = act;

    // TODO: All onRegister calls here have to be replaced with modules

    DefaultTimer().onRegister(act);

    await _registerModule(PlatformLoggerModule());
    await _registerModule(CoreModule());

    await _registerModule(ApiModule());
    await _registerModule(ListModule());
    await _registerModule(FilterModule());

    // Then family-only deps (for now at least)
    if (act.isFamily) {
      await _registerModule(ProfileModule());
      await _registerModule(CustomlistModule());
      await _registerModule(DeviceModule());
      await _registerModule(AuthModule());
      await _registerModule(StatsModule());
      await _registerModule(JournalModule());
      await _registerModule(PermModule());
      await _registerModule(SupportModule());
    }

    await _registerModule(PlatformPersistenceModule());

    if (act.hasToys) {
      RepeatingHttpService(
        DebugHttpService(PlatformHttpService()),
        maxRetries: cfg.httpMaxRetries,
        waitTime: cfg.httpRetryDelay,
      ).onRegister(act);
    } else {
      RepeatingHttpService(
        PlatformHttpService(),
        maxRetries: cfg.httpMaxRetries,
        waitTime: cfg.httpRetryDelay,
      ).onRegister(act);
    }

    // The stores. Order is important
    EnvStore().onRegister(act);
    StageStore().onRegister(act);
    AccountStore().onRegister(act);
    NotificationStore().onRegister(act);
    AccountPaymentStore().onRegister(act);
    AccountRefreshStore().onRegister(act);
    DeviceStore().onRegister(act);

    await _registerModule(AccountModule());

    // Compatibility layer for v6 (temporary)
    if (!act.isFamily) {
      await _registerModule(PlatformFilterModule());
    }

    AppStore().onRegister(act);
    AppStartStore().onRegister(act);
    PrivateDnsCheck().onRegister(act);
    await _registerModule(PlatformPermModule());
    await _registerModule(LockModule());
    CustomStore().onRegister(act);

    if (!act.isFamily) {
      JournalStore().onRegister(act);
      PlusStore().onRegister(act);
      PlusKeypairStore().onRegister(act);
      PlusGatewayStore().onRegister(act);
      PlusLeaseStore().onRegister(act);
      PlusVpnStore().onRegister(act);
      HomeStore().onRegister(act);
    }

    StatsStore().onRegister(act);
    StatsRefreshStore().onRegister(act);

    if (act.isFamily) {
      await _registerModule(FamilyModule());
    }

    await _registerModule(RateModule());
    await _registerModule(PlatformRateModule());
    CommandStore().onRegister(act);
    LinkStore().onRegister(act);

    DI.register<TopBarController>(TopBarController());
  }

  start(Marker m) async {
    await _appStart.startApp(m);

    await log(m).trace("startModules", (m) async {
      for (var mod in _modules) {
        await log(m).trace("${mod.runtimeType}", (m) async {
          await mod.start(m);
        });
      }
    });

    if (act.isFamily) {
      await DI.get<SupportUnreadActor>().onStart(m);
      await DI.get<PurchaseTimeoutActor>().onStart(m);
    }

    log(m).t("All modules started");
  }

  late final Act act;
  final _modules = <Module>[];
  _add(Module module) {
    _modules.add(module);
  }

  _registerModule(Module module) async {
    await module.create(act);
    _add(module);
  }
}
