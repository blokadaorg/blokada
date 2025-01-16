import 'package:common/common/api/api.dart';
import 'package:common/common/module/account/account.dart';
import 'package:common/common/module/customlist/customlist.dart';
import 'package:common/common/module/filter/filter.dart';
import 'package:common/common/module/journal/journal.dart';
import 'package:common/common/module/list/list.dart';
import 'package:common/common/module/lock/lock.dart';
import 'package:common/common/module/perm/perm.dart';
import 'package:common/common/module/rate/rate.dart';
import 'package:common/common/module/support/support.dart';
import 'package:common/common/widget/top_bar.dart';
import 'package:common/core/core.dart';
import 'package:common/family/module/auth/auth.dart';
import 'package:common/family/module/device_v3/device.dart';
import 'package:common/family/module/family/family.dart';
import 'package:common/family/module/perm/perm.dart';
import 'package:common/family/module/profile/profile.dart';
import 'package:common/family/module/stats/stats.dart';
import 'package:common/platform/filter/filter.dart';
import 'package:common/platform/logger/logger.dart';
import 'package:common/platform/perm/dnscheck.dart';
import 'package:common/platform/persistence/persistence.dart';
import 'package:common/v6/module/perm/perm.dart';
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

class Modules with Logging {
  late final _appStart = Core.get<AppStartStore>();

  create(Act act) async {
    Core.act = act;
    Core.config = Config();

    // TODO: All onRegister calls here have to be replaced with modules

    await _registerModule(PlatformLoggerModule());
    await _registerModule(CoreModule());

    await _registerModule(ApiModule());
    await _registerModule(ListModule());
    await _registerModule(FilterModule());
    await _registerModule(JournalModule());
    await _registerModule(CustomlistModule());
    await _registerModule(SupportModule());

    // Then family-only deps (for now at least)
    if (Core.act.isFamily) {
      await _registerModule(ProfileModule());
      await _registerModule(DeviceModule());
      await _registerModule(AuthModule());
      await _registerModule(StatsModule());
      await _registerModule(PermModule());
    }

    await _registerModule(PlatformPersistenceModule());

    if (Core.act.hasToys) {
      RepeatingHttpService(
        DebugHttpService(PlatformHttpService()),
        maxRetries: Core.config.httpMaxRetries,
        waitTime: Core.config.httpRetryDelay,
      ).onRegister();
    } else {
      RepeatingHttpService(
        PlatformHttpService(),
        maxRetries: Core.config.httpMaxRetries,
        waitTime: Core.config.httpRetryDelay,
      ).onRegister();
    }

    // The stores. Order is important
    EnvStore().onRegister();
    StageStore().onRegister();
    AccountStore().onRegister();
    NotificationStore().onRegister();
    AccountPaymentStore().onRegister();
    AccountRefreshStore().onRegister();
    DeviceStore().onRegister();

    await _registerModule(AccountModule());

    // Compatibility layer for v6 (temporary)
    if (!Core.act.isFamily) {
      await _registerModule(PlatformFilterModule());
    }

    AppStore().onRegister();
    AppStartStore().onRegister();
    PrivateDnsCheck().onRegister();
    await _registerModule(CommonPermModule());
    await _registerModule(PlatformPermModule());
    await _registerModule(LockModule());
    CustomStore().onRegister();

    if (!Core.act.isFamily) {
      await _registerModule(V6PermModule());
      PlusStore().onRegister();
      PlusKeypairStore().onRegister();
      PlusGatewayStore().onRegister();
      PlusLeaseStore().onRegister();
      PlusVpnStore().onRegister();
      HomeStore().onRegister();
    }

    StatsStore().onRegister();
    StatsRefreshStore().onRegister();

    if (Core.act.isFamily) {
      await _registerModule(FamilyModule());
    }

    await _registerModule(RateModule());
    await _registerModule(PlatformRateModule());
    CommandStore().onRegister();
    LinkStore().onRegister();

    Core.register<TopBarController>(TopBarController());
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

    if (Core.act.isFamily) {
      await Core.get<SupportUnreadActor>().onStart(m);
      await Core.get<PurchaseTimeoutActor>().onStart(m);
    }

    log(m).t("All modules started");
  }

  final _modules = <Module>[];
  _add(Module module) {
    _modules.add(module);
  }

  _registerModule(Module module) async {
    await module.create();
    _add(module);
  }
}
