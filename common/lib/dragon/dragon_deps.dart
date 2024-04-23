import 'package:common/common/defaults/filter_defaults.dart';
import 'package:common/common/model.dart';
import 'package:common/dragon/account/account_id.dart';
import 'package:common/dragon/account/controller.dart';
import 'package:common/dragon/api/api.dart';
import 'package:common/dragon/api/http.dart';
import 'package:common/dragon/api/user_agent.dart';
import 'package:common/dragon/auth/api.dart';
import 'package:common/dragon/auth/controller.dart';
import 'package:common/dragon/base_url.dart';
import 'package:common/dragon/device/api.dart';
import 'package:common/dragon/device/controller.dart';
import 'package:common/dragon/device/current_config.dart';
import 'package:common/dragon/device/current_token.dart';
import 'package:common/dragon/device/generator.dart';
import 'package:common/dragon/device/open_perms.dart';
import 'package:common/dragon/device/selected_device.dart';
import 'package:common/dragon/device/this_device.dart';
import 'package:common/dragon/filter/controller.dart';
import 'package:common/dragon/filter/selected_filters.dart';
import 'package:common/dragon/journal/api.dart';
import 'package:common/dragon/journal/controller.dart';
import 'package:common/dragon/list/api.dart';
import 'package:common/dragon/perm/controller.dart';
import 'package:common/dragon/perm/dns_perm.dart';
import 'package:common/dragon/persistence/persistence.dart';
import 'package:common/dragon/profile/api.dart';
import 'package:common/dragon/profile/controller.dart';
import 'package:common/dragon/scheduler.dart';
import 'package:common/dragon/stats/api.dart';
import 'package:common/dragon/stats/controller.dart';
import 'package:common/util/di.dart';

class DragonDeps {
  register(Act act) {
    depend<Act>(act);

    depend<BaseUrl>(BaseUrl(act));
    depend<UserAgent>(UserAgent());
    depend<ApiRetryDuration>(ApiRetryDuration(act));

    depend<AccountId>(AccountId());
    depend<AccountController>(AccountController());
    depend<Http>(Http());

    depend<Api>(Api());
    depend<ListApi>(ListApi());
    depend<DeviceApi>(DeviceApi());

    depend<KnownFilters>(KnownFilters(
      isFamily: act.isFamily(),
      isIos: act.getPlatform() == Platform.ios,
    ));
    depend<DefaultFilters>(DefaultFilters(act.isFamily()));
    depend<SelectedFilters>(SelectedFilters());
    depend<CurrentConfig>(CurrentConfig());
    depend<FilterController>(FilterController());

    depend<Persistence>(Persistence(isSecure: false));

    depend<ProfileApi>(ProfileApi());
    depend<ProfileController>(ProfileController());

    depend<NameGenerator>(NameGenerator());
    depend<OpenPerms>(OpenPerms());
    depend<ThisDevice>(ThisDevice());
    depend<SelectedDeviceTag>(SelectedDeviceTag());

    depend<AuthApi>(AuthApi());
    depend<CurrentToken>(CurrentToken());
    depend<DeviceController>(DeviceController());
    depend<AuthController>(AuthController());

    depend<StatsApi>(StatsApi());
    depend<StatsController>(StatsController());

    depend<JournalApi>(JournalApi());
    depend<JournalController>(JournalController());

    depend<DnsPerm>(DnsPerm());
    depend<PermController>(PermController());

    depend<Scheduler>(Scheduler(timer: SchedulerTimer()));
  }
}
