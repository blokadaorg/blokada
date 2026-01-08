import 'package:common/src/features/account/domain/account.dart';
import 'package:common/src/features/api/domain/api.dart';
import 'package:common/src/features/config/domain/config.dart';
import 'package:common/src/features/customlist/domain/customlist.dart';
import 'package:common/src/features/env/domain/env.dart';
import 'package:common/src/features/filter/domain/filter.dart';
import 'package:common/src/features/journal/domain/journal.dart';
import 'package:common/src/features/link/domain/link.dart';
import 'package:common/src/features/list/domain/list.dart';
import 'package:common/src/features/lock/domain/lock.dart';
import 'package:common/src/features/modal/domain/modal.dart';
import 'package:common/src/features/notification/domain/notification.dart';
import 'package:common/src/features/onboard/domain/onboard.dart';
import 'package:common/src/features/payment/domain/payment.dart';
import 'package:common/src/features/perm/domain/perm.dart';
import 'package:common/src/features/rate/domain/rate.dart';
import 'package:common/src/features/safari/domain/safari.dart';
import 'package:common/src/features/support/domain/support.dart';
import 'package:common/src/shared/ui/top_bar.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/app_variants/family/module/auth/auth.dart';
import 'package:common/src/app_variants/family/module/device_v3/device.dart';
import 'package:common/src/app_variants/family/module/family/family.dart';
import 'package:common/src/app_variants/family/module/perm/perm.dart';
import 'package:common/src/app_variants/family/module/profile/profile.dart';
import 'package:common/src/app_variants/family/module/qrscan/qrscan.dart';
import 'package:common/src/app_variants/family/module/stats/stats.dart';
import 'package:common/src/platform/common/common.dart';
import 'package:common/src/platform/core/core.dart';
import 'package:common/src/platform/family/family.dart';
import 'package:common/src/platform/filter/filter.dart';
import 'package:common/src/platform/payment/payment.dart';
import 'package:common/src/platform/perm/dnscheck.dart';
import 'package:common/src/platform/plus/plus.dart';
import 'package:common/src/platform/safari/safari.dart';
import 'package:common/src/features/plus/domain/plus.dart';
import 'package:common/src/app_variants/v6/module/freemium/freemium.dart';
import 'package:common/src/app_variants/v6/module/onboard/onboard.dart';
import 'package:common/src/app_variants/v6/widget/home/home.dart';

import 'package:common/src/platform/account/account.dart';
import 'package:common/src/platform/account/refresh/refresh.dart';
import 'package:common/src/platform/app/app.dart';
import 'package:common/src/platform/app/start/start.dart';
import 'package:common/src/platform/command/command.dart';
import 'package:common/src/platform/device/device.dart';
import 'package:common/src/platform/perm/perm.dart';
import 'package:common/src/platform/stage/stage.dart';
import 'package:common/src/platform/stats/stats.dart';
import 'package:common/src/platform/stats/toplist_store.dart';
import 'package:common/src/platform/stats/delta_store.dart';

class Modules with Logging {
  late final _appStart = Core.get<AppStartStore>();

  create(Act act) async {
    Core.act = act;
    Core.config = CoreConfig();

    // TODO: All onRegister calls here have to be replaced with modules

    await _registerModule(CoreModule());
    await _registerModule(PlatformCoreModule());
    await _registerModule(ConfigModule());
    await _registerModule(EnvModule());
    await _registerModule(LockModule());
    await _registerModule(NotificationModule());
    await _registerModule(ApiModule());

    if (!Core.act.isFamily) {
      await _registerModule(OnboardModule());
    }

    await _registerModule(ModalModule());
    await _registerModule(ListModule());
    await _registerModule(FilterModule());
    await _registerModule(JournalModule());
    await _registerModule(CustomlistModule());
    await _registerModule(SupportModule());

    // The stores. Order is important
    StageStore().onRegister();
    AccountStore().onRegister();
    await _registerModule(AccountModule());
    AccountRefreshStore().onRegister();
    DeviceStore().onRegister();

    await _registerModule(PaymentModule());

    // Then family-only deps (for now at least)
    if (Core.act.isFamily) {
      await _registerModule(ProfileModule());
      await _registerModule(DeviceModule());
      await _registerModule(AuthModule());
      await _registerModule(StatsModule());
      await _registerModule(PermModule());
    }

    await _registerModule(PlatformCommonModule());

    // Compatibility layer for v6 (temporary)
    if (!Core.act.isFamily) {
      await _registerModule(PlatformFilterModule());
    }

    await _registerModule(PlatformPaymentModule());

    AppStore().onRegister();
    AppStartStore().onRegister();
    PrivateDnsCheck().onRegister();
    await _registerModule(CommonPermModule());
    await _registerModule(PlatformPermModule());

    if (!Core.act.isFamily) {
      await _registerModule(V6OnboardModule());
      await _registerModule(PlusModule());
      await _registerModule(PlatformPlusModule());
      HomeStore().onRegister();
    }

    StatsStore().onRegister();
    ToplistStore().onRegister();
    StatsDeltaStore().onRegister();

    if (Core.act.isFamily) {
      await _registerModule(FamilyModule());
      await _registerModule(PlatformFamilyModule());
      await _registerModule(QrScanModule());
    }

    await _registerModule(RateModule());
    await _registerModule(LinkModule());

    if (Core.act.isIos) {
      await _registerModule(SafariModule());
      await _registerModule(PlatformSafariModule());
      await _registerModule(FreemiumModule());
    }

    CommandStore().onRegister();

    Core.register<TopBarController>(TopBarController());
  }

  start(Marker m) async {
    log(m).t("Starting modules...");

    for (var mod in _modules) {
      await log(m).trace("${mod.runtimeType}", (m) async {
        // Hack to be refactored
        if (mod.runtimeType == AccountModule) {
          log(m).i("Starting legacy device store");
          final legacyDevice = Core.get<DeviceStore>();
          await legacyDevice.start(m);
        }

        await mod.start(m);

        // Hack to be refactored
        if (mod.runtimeType == AccountModule) {
          log(m).i("Starting legacy account refresh store");
          final legacyAccount = Core.get<AccountRefreshStore>();
          await legacyAccount.start(m);
        }
      });
    }

    await _appStart.startApp(m); // TODO: refactor this

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
