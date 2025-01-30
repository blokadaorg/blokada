import 'package:common/common/module/account/account.dart';
import 'package:common/common/module/api/api.dart';
import 'package:common/common/module/customlist/customlist.dart';
import 'package:common/common/module/env/env.dart';
import 'package:common/common/module/filter/filter.dart';
import 'package:common/common/module/journal/journal.dart';
import 'package:common/common/module/link/link.dart';
import 'package:common/common/module/list/list.dart';
import 'package:common/common/module/lock/lock.dart';
import 'package:common/common/module/notification/notification.dart';
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
import 'package:common/platform/common/common.dart';
import 'package:common/platform/core/core.dart';
import 'package:common/platform/family/family.dart';
import 'package:common/platform/filter/filter.dart';
import 'package:common/platform/perm/dnscheck.dart';
import 'package:common/platform/plus/plus.dart';
import 'package:common/plus/plus.dart';
import 'package:common/v6/module/perm/perm.dart';
import 'package:common/v6/widget/home/home.dart';

import 'platform/account/account.dart';
import 'platform/account/refresh/refresh.dart';
import 'platform/app/app.dart';
import 'platform/app/start/start.dart';
import 'platform/command/command.dart';
import 'platform/device/device.dart';
import 'platform/payment/payment.dart';
import 'platform/perm/perm.dart';
import 'platform/stage/stage.dart';
import 'platform/stats/refresh/refresh.dart';
import 'platform/stats/stats.dart';

class Modules with Logging {
  late final _appStart = Core.get<AppStartStore>();

  create(Act act) async {
    Core.act = act;
    Core.config = Config();

    // TODO: All onRegister calls here have to be replaced with modules

    await _registerModule(CoreModule());
    await _registerModule(PlatformCoreModule());
    await _registerModule(EnvModule());
    await _registerModule(NotificationModule());

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

    await _registerModule(PlatformCommonModule());

    await _registerModule(AccountModule());

    // The stores. Order is important
    StageStore().onRegister();
    AccountStore().onRegister();
    AccountPaymentStore().onRegister();
    AccountRefreshStore().onRegister();
    DeviceStore().onRegister();

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

    if (!Core.act.isFamily) {
      await _registerModule(V6PermModule());
      await _registerModule(PlusModule());
      await _registerModule(PlatformPlusModule());
      HomeStore().onRegister();
    }

    StatsStore().onRegister();
    StatsRefreshStore().onRegister();

    if (Core.act.isFamily) {
      await _registerModule(FamilyModule());
      await _registerModule(PlatformFamilyModule());
    }

    await _registerModule(RateModule());
    await _registerModule(LinkModule());
    CommandStore().onRegister();

    Core.register<TopBarController>(TopBarController());
  }

  start(Marker m) async {
    _appStart.startApp(m); // TODO: refactor this

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
    final submodules = await module.onRegisterSubmodules();
    for (var sub in submodules) {
      await _registerModule(sub);
    }

    await module.create();
    _add(module);
  }
}
