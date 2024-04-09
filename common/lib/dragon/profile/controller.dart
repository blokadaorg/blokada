import 'package:collection/collection.dart';
import 'package:common/common/defaults/filter_defaults.dart';
import 'package:common/common/model.dart';
import 'package:common/dragon/device/current_config.dart';
import 'package:common/dragon/filter/controller.dart';
import 'package:common/dragon/profile/api.dart';
import 'package:common/util/di.dart';

class ProfileController {
  late final _profiles = dep<ProfileApi>();
  late final _defaultFilters = dep<DefaultFilters>();
  late final _filters = dep<FilterController>();
  late final _userConfig = dep<CurrentConfig>();

  List<JsonProfile> profiles = [];

  late JsonProfile _selected;

  Function onChange = () {};

  reload() async {
    profiles = await _profiles.fetch();
  }

  JsonProfile get(String pId) {
    final p = profiles.firstWhereOrNull((it) => it.profileId == pId);
    if (p == null) throw Exception("Profile $pId not found");
    return p;
  }

  Future<JsonProfile> addProfile(String template, String alias,
      {bool canReuse = false}) async {
    if (canReuse) {
      final existing =
          profiles.firstWhereOrNull((it) => it.displayAlias == alias);
      if (existing != null) return existing;
    }

    final defaultFilters = _defaultFilters.getTemplate(template);
    final config = await _filters.getConfig(defaultFilters);

    print(
        "in profile controller: ${config.configs}, so: ${config.configs[FilterConfigKey.safeSearch] ?? false}");
    final p = await _profiles.add(JsonProfilePayload.forCreate(
      alias: generateProfileAlias(alias, template),
      lists: config.lists.toList(),
      safeSearch: config.configs[FilterConfigKey.safeSearch] ?? false,
    ));
    profiles.add(p);
    onChange();
    return p;
  }

  Future<JsonProfile> renameProfile(JsonProfile profile, String alias) async {
    if (profile.displayAlias == alias) return profile;
    if (!profiles.any((it) => it.profileId == profile.profileId)) {
      throw Exception("Profile ${profile.profileId} not found");
    }

    final p = await _profiles.rename(profile, alias);
    profiles =
        profiles.map((it) => it.profileId == p.profileId ? p : it).toList();
    onChange();
    return p;
  }

  deleteProfile(JsonProfile profile) async {
    await _profiles.delete(profile);
    profiles =
        profiles.where((it) => it.profileId != profile.profileId).toList();
    onChange();
  }

  selectProfile(JsonProfile profile) {
    print("selecting profile ${profile.alias}");
    final config = UserFilterConfig(profile.lists.toSet(), {
      FilterConfigKey.safeSearch: profile.safeSearch,
    });
    _userConfig.now = config;
    _selected = profile;
    print("user config set to ${config.configs}");
    // Setting user config causes FilterController to reload
  }

  updateUserChoice(List<FilterSelection> selections) async {
    print("updating user choice: $selections");

    final config = await _filters.getConfig(selections);
    final p = await _profiles.update(_selected.copy(
      lists: config.lists.toList(),
      safeSearch: config.configs[FilterConfigKey.safeSearch] ?? false,
    ));
    profiles =
        profiles.map((it) => it.profileId == p.profileId ? p : it).toList();
    _userConfig.now = config;
    onChange();
  }
}
