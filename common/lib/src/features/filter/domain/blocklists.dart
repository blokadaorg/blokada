part of 'filter.dart';

/// One option of one v6 filter, the unit the v6 blocklists screen shows as a
/// row. The screen splits these into a required main list and optional
/// extras; the server still gets one flat list.
class BlocklistKey {
  final FilterName filterName;
  final OptionName optionName;

  const BlocklistKey(this.filterName, this.optionName);

  /// Stored form for [BlocklistMainPick], like "oisd/small".
  String get tag => "$filterName/$optionName";

  static BlocklistKey? fromTag(String? tag) {
    if (tag == null) return null;
    final at = tag.indexOf("/");
    if (at <= 0 || at == tag.length - 1) return null;
    return BlocklistKey(tag.substring(0, at), tag.substring(at + 1));
  }

  @override
  bool operator ==(Object other) =>
      other is BlocklistKey && other.filterName == filterName && other.optionName == optionName;

  @override
  int get hashCode => Object.hash(filterName, optionName);

  @override
  String toString() => tag;
}

/// The general lists that can be the main blocklist. The order decides which
/// one is main when an account has several on and no pick was saved.
const v6MainBlocklists = [
  BlocklistKey("oisd", "small"),
  BlocklistKey("oisd", "big"),
  BlocklistKey("stevenblack", "unified"),
  BlocklistKey("1hosts", "lite"),
  BlocklistKey("1hosts", "pro"),
  BlocklistKey("hblock", "standard"),
];

/// What an extra blocks. Extras are grouped by this, not by provider.
enum BlocklistGroup {
  // The main lists not picked as main.
  general("blocklists group general"),
  ads("blocklists group ads"),
  security("blocklists group security"),
  adult("blocklists group adult"),
  social("blocklists group social"),
  gambling("blocklists group gambling"),
  fakeNews("blocklists group fake news"),
  apps("blocklists group apps"),
  // Options this table does not know yet, so a new one still shows up.
  other("blocklists group other");

  final String titleKey;

  const BlocklistGroup(this.titleKey);
}

final _v6Groups = <BlocklistKey, BlocklistGroup>{
  BlocklistKey("goodbyeads", "standard"): BlocklistGroup.ads,
  BlocklistKey("adaway", "standard"): BlocklistGroup.ads,
  BlocklistKey("blocklist", "ads"): BlocklistGroup.ads,
  BlocklistKey("blocklist", "tracking"): BlocklistGroup.ads,
  BlocklistKey("blacklist", "adservers"): BlocklistGroup.ads,
  BlocklistKey("developerdan", "ads and tracking"): BlocklistGroup.ads,
  BlocklistKey("ddgtrackerradar", "standard"): BlocklistGroup.ads,
  BlocklistKey("danpollock", "standard"): BlocklistGroup.ads,
  BlocklistKey("cpbl", "standard"): BlocklistGroup.ads,
  BlocklistKey("cpbl", "mini"): BlocklistGroup.ads,
  BlocklistKey("d3host", "standard"): BlocklistGroup.ads,
  BlocklistKey("phishingarmy", "standard"): BlocklistGroup.security,
  BlocklistKey("phishingarmy", "extended"): BlocklistGroup.security,
  BlocklistKey("blocklist", "malware"): BlocklistGroup.security,
  BlocklistKey("blocklist", "phishing"): BlocklistGroup.security,
  BlocklistKey("spam404", "standard"): BlocklistGroup.security,
  BlocklistKey("urlhaus", "standard"): BlocklistGroup.security,
  BlocklistKey("oisd", "nsfw"): BlocklistGroup.adult,
  BlocklistKey("stevenblack", "adult"): BlocklistGroup.adult,
  BlocklistKey("stevenblack", "social"): BlocklistGroup.social,
  BlocklistKey("blacklist", "facebook"): BlocklistGroup.social,
  BlocklistKey("developerdan", "facebook"): BlocklistGroup.social,
  BlocklistKey("blocklist", "facebook"): BlocklistGroup.social,
  BlocklistKey("stevenblack", "gambling"): BlocklistGroup.gambling,
  BlocklistKey("stevenblack", "fake news"): BlocklistGroup.fakeNews,
  BlocklistKey("developerdan", "hate and junk"): BlocklistGroup.fakeNews,
  BlocklistKey("goodbyeads", "samsung"): BlocklistGroup.apps,
  BlocklistKey("goodbyeads", "xiaomi"): BlocklistGroup.apps,
  BlocklistKey("goodbyeads", "spotify"): BlocklistGroup.apps,
  BlocklistKey("goodbyeads", "youtube"): BlocklistGroup.apps,
  BlocklistKey("blocklist", "youtube"): BlocklistGroup.apps,
  BlocklistKey("developerdan", "amp"): BlocklistGroup.apps,
};

BlocklistGroup v6BlocklistGroup(BlocklistKey key) {
  if (v6MainBlocklists.contains(key)) return BlocklistGroup.general;
  return _v6Groups[key] ?? BlocklistGroup.other;
}

/// Every option the filters offer, as keys.
List<BlocklistKey> blocklistKeys(List<Filter> filters) => [
  for (final filter in filters)
    for (final option in filter.options) BlocklistKey(filter.filterName, option.optionName),
];

/// The options that are on in [selected].
Set<BlocklistKey> selectedBlocklists(List<FilterSelection> selected) => {
  for (final selection in selected)
    for (final option in selection.options) BlocklistKey(selection.filterName, option),
};

/// The main list for [selected]: the saved [pick] while it is still on, else
/// the first one on in [v6MainBlocklists] order. Null when no main list is
/// on; the screen then asks the user to pick one rather than picking it.
BlocklistKey? v6MainBlocklist(List<FilterSelection> selected, {BlocklistKey? pick}) {
  final on = selectedBlocklists(selected);
  if (pick != null && v6MainBlocklists.contains(pick) && on.contains(pick)) {
    return pick;
  }
  return v6MainBlocklists.firstWhereOrNull(on.contains);
}

/// [selected] with [key] turned on or off, as a new list.
List<FilterSelection> withBlocklist(List<FilterSelection> selected, BlocklistKey key, bool on) {
  final result = selected.toList();
  final index = result.indexWhere((it) => it.filterName == key.filterName);
  final old = index == -1 ? <String>[] : result[index].options;
  final options = old.where((it) => it != key.optionName).toList();
  if (on) options.add(key.optionName);
  final updated = FilterSelection(key.filterName, options);
  if (index == -1) {
    result.add(updated);
  } else {
    result[index] = updated;
  }
  return result;
}

/// The name a row shows, like "OISD Small", or just the provider when it has
/// one option or the option is its "standard" list.
String blocklistName(BlocklistKey key, List<Filter> filters) {
  final title =
      filterDecorDefaults.firstWhereOrNull((it) => it.filterName == key.filterName)?.title.i18n ??
      key.filterName.firstLetterUppercase();
  final filter = filters.firstWhereOrNull((it) => it.filterName == key.filterName);
  if (key.optionName == "standard" || (filter?.options.length ?? 0) == 1) {
    return title;
  }
  final option = filterOptionDecorDefaults[key.optionName] ?? key.optionName.firstLetterUppercase();
  return "$title ${option.i18n}";
}

/// One line on what a list blocks or risks, or null when there is none, so
/// the row shows its name only. Options come from the api, so most have none.
String? blocklistBrief(BlocklistKey key) {
  final id = "blocklist brief ${key.filterName} ${key.optionName}";
  final text = id.i18n;
  return text == id ? null : text;
}
