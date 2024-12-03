part of 'profile.dart';

class ProfileActor with Logging, Actor {
  late final _profiles = Core.get<ProfileApi>();
  late final _defaultFilters = Core.get<DefaultFilters>();
  late final _filters = Core.get<FilterActor>();
  late final _userConfig = Core.get<CurrentConfig>();
  late final _selectedFilters = Core.get<SelectedFilters>();

  List<JsonProfile> profiles = [];

  late JsonProfile _selected;

  Function onChange = () {};

  reload(Marker m) async {
    profiles = await _profiles.fetch(m);
  }

  JsonProfile get(String pId) {
    final p = profiles.firstWhereOrNull((it) => it.profileId == pId);
    if (p == null) throw Exception("Profile $pId not found");
    return p;
  }

  Future<JsonProfile> addProfile(String template, String alias, Marker m,
      {bool canReuse = false}) async {
    if (canReuse) {
      final existing =
          profiles.firstWhereOrNull((it) => it.displayAlias == alias);
      if (existing != null) return existing;
    }

    final defaultFilters = _defaultFilters.getTemplate(template);
    final config = await _filters.getConfig(defaultFilters, m);

    log(m).i(
        "in profile controller: ${config.configs}, so: ${config.configs[FilterConfigKey.safeSearch] ?? false}");
    final p = await _profiles.add(
        m,
        JsonProfilePayload.forCreate(
          alias: generateProfileAlias(alias, template),
          lists: config.lists.toList(),
          safeSearch: config.configs[FilterConfigKey.safeSearch] ?? false,
        ));
    profiles.add(p);
    onChange();
    return p;
  }

  Future<JsonProfile> renameProfile(
      Marker m, JsonProfile profile, String alias) async {
    if (profile.displayAlias == alias) return profile;
    if (!profiles.any((it) => it.profileId == profile.profileId)) {
      throw Exception("Profile ${profile.profileId} not found");
    }

    final p = await _profiles.rename(m, profile, alias);
    profiles =
        profiles.map((it) => it.profileId == p.profileId ? p : it).toList();
    onChange();
    return p;
  }

  deleteProfile(Marker m, JsonProfile profile) async {
    await _profiles.delete(m, profile);
    profiles =
        profiles.where((it) => it.profileId != profile.profileId).toList();
    onChange();
  }

  selectProfile(Marker m, JsonProfile profile) async {
    await log(m).trace("selectProfile", (m) async {
      await log(m).i("selecting profile ${profile.alias}");
      final config = UserFilterConfig(profile.lists.toSet(), {
        FilterConfigKey.safeSearch: profile.safeSearch,
      });
      _userConfig.change(m, config);
      _selected = profile;
      log(m).i("user config set to ${config.configs}");
      // Setting user config causes FilterController to reload
    });
  }

  updateUserChoice(Filter filter, List<String> options, Marker m) async {
    final selected = await _selectedFilters.now();
    // Immediate UI feedback
    final old = selected.firstWhere((it) => it.filterName == filter.filterName);
    _selectedFilters.change(
        m,
        selected
          ..removeWhere((it) => it.filterName == filter.filterName)
          ..add(FilterSelection(filter.filterName, options)));

    try {
      final config = await _filters.getConfig(await _selectedFilters.now(), m);
      final p = await _profiles.update(
          m,
          _selected.copy(
            lists: config.lists.toList(),
            safeSearch: config.configs[FilterConfigKey.safeSearch] ?? false,
          ));
      profiles =
          profiles.map((it) => it.profileId == p.profileId ? p : it).toList();
      _userConfig.change(m, config);
      onChange();
    } catch (e) {
      _selectedFilters.change(
          m,
          await _selectedFilters.now()
            ..removeWhere((it) => it.filterName == filter.filterName)
            ..add(old));
    }
  }
}
