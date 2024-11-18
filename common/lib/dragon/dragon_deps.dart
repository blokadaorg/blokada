import 'package:common/common/api/api.dart';
import 'package:common/common/defaults/filter_defaults.dart';
import 'package:common/common/model/model.dart';
import 'package:common/common/state/state.dart';
import 'package:common/core/core.dart';
import 'package:common/dragon/account/controller.dart';
import 'package:common/dragon/auth/api.dart';
import 'package:common/dragon/auth/controller.dart';
import 'package:common/dragon/customlist/api.dart';
import 'package:common/dragon/customlist/controller.dart';
import 'package:common/dragon/device/api.dart';
import 'package:common/dragon/device/controller.dart';
import 'package:common/dragon/device/current_config.dart';
import 'package:common/dragon/device/current_token.dart';
import 'package:common/dragon/device/generator.dart';
import 'package:common/dragon/device/open_perms.dart';
import 'package:common/dragon/device/selected_device.dart';
import 'package:common/dragon/device/slidable_onboarding.dart';
import 'package:common/dragon/device/this_device.dart';
import 'package:common/dragon/filter/controller.dart';
import 'package:common/dragon/filter/selected_filters.dart';
import 'package:common/dragon/journal/api.dart';
import 'package:common/dragon/journal/controller.dart';
import 'package:common/dragon/list/api.dart';
import 'package:common/dragon/perm/controller.dart';
import 'package:common/dragon/perm/dns_perm.dart';
import 'package:common/dragon/profile/api.dart';
import 'package:common/dragon/profile/controller.dart';
import 'package:common/dragon/stats/api.dart';
import 'package:common/dragon/stats/controller.dart';
import 'package:common/dragon/support/api.dart';
import 'package:common/dragon/support/chat_history.dart';
import 'package:common/dragon/support/controller.dart';
import 'package:common/dragon/support/current_session.dart';
import 'package:common/dragon/support/purchase_timeout.dart';
import 'package:common/dragon/support/support_unread.dart';

class DragonDeps {
  DragonDeps register(Act act) {
    // First, deps that are also used in v6
    // currently only for backwards-migrating the new Filters
    // that replace the old Decks/Packs concept

    DI.register<Act>(act);

    DI.register<BaseUrl>(BaseUrl(act));
    DI.register<UserAgent>(UserAgent());
    DI.register<ApiRetryDuration>(ApiRetryDuration(act));

    DI.register<AccountId>(AccountId());
    DI.register<AccountController>(AccountController());
    DI.register<Http>(Http());

    DI.register<Api>(Api());
    DI.register<ListApi>(ListApi());

    DI.register<KnownFilters>(KnownFilters(
      isFamily: act.isFamily,
      isIos: act.platform == PlatformType.iOS,
    ));
    DI.register<DefaultFilters>(DefaultFilters(act.isFamily));
    DI.register<SelectedFilters>(SelectedFilters());
    DI.register<CurrentConfig>(CurrentConfig());
    DI.register<FilterController>(FilterController());

    // Then family-only deps (for now at least)
    if (act.isFamily) {
      DI.register<DeviceApi>(DeviceApi());

      DI.register<ProfileApi>(ProfileApi());
      DI.register<ProfileController>(ProfileController());

      DI.register<CustomListApi>(CustomListApi());
      DI.register<CustomListController>(CustomListController());

      DI.register<NameGenerator>(NameGenerator());
      DI.register<OpenPerms>(OpenPerms());
      DI.register<ThisDevice>(ThisDevice());
      DI.register<SelectedDeviceTag>(SelectedDeviceTag());
      DI.register<SlidableOnboarding>(SlidableOnboarding());

      DI.register<AuthApi>(AuthApi());
      DI.register<CurrentToken>(CurrentToken());
      DI.register<DeviceController>(DeviceController());
      DI.register<AuthController>(AuthController());

      DI.register<StatsApi>(StatsApi());
      DI.register<StatsController>(StatsController());

      DI.register<JournalApi>(JournalApi());
      DI.register<JournalController>(JournalController());

      DI.register<DnsPerm>(DnsPerm());
      DI.register<PermController>(PermController());

      DI.register<Scheduler>(Scheduler(timer: SchedulerTimer()));

      DI.register<SupportApi>(SupportApi());
      DI.register<SupportController>(SupportController());
      DI.register<CurrentSession>(CurrentSession());
      DI.register<ChatHistory>(ChatHistory());
      DI.register<SupportUnread>(SupportUnread());
      DI.register<SupportUnreadController>(SupportUnreadController());
      DI.register<PurchaseTimout>(PurchaseTimout());
    }

    return this;
  }

  load(Act act) {
    if (act.isFamily) {
      DI.get<SupportUnreadController>().load();
      DI.get<PurchaseTimout>().load();
    }
  }
}
