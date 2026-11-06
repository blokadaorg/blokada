part of 'activation.dart';

/// The answers to "What do you want gone?", in plain words instead of list
/// names. Each maps to one extra blocklist of the Advanced screen, so a
/// goal is undone or refined there like any other list. The main list
/// (OISD Small by default) already covers common ads and trackers; these
/// add the narrower lists for what the user said matters to them.
enum ActivationGoal {
  /// GoodbyeAds targets ads served inside mobile apps and games.
  appAds("activation goal app ads", BlocklistKey("goodbyeads", "standard")),

  /// DuckDuckGo Tracker Radar: the trackers DuckDuckGo finds across sites.
  trackers("activation goal trackers", BlocklistKey("ddgtrackerradar", "standard")),

  /// Phishing Army: phishing and scam domains.
  scams("activation goal scams", BlocklistKey("phishingarmy", "standard")),

  /// OISD NSFW: adult sites.
  adult("activation goal adult", BlocklistKey("oisd", "nsfw"));

  final String titleKey;
  final BlocklistKey blocklist;

  const ActivationGoal(this.titleKey, this.blocklist);
}

/// The extra blocklists to flip so that [on] matches [picked]: true turns a
/// list on, false off. Lists the goals don't cover are left alone.
Map<BlocklistKey, bool> goalChanges(Set<ActivationGoal> picked, Set<BlocklistKey> on) => {
  for (final goal in ActivationGoal.values)
    if (picked.contains(goal) != on.contains(goal.blocklist)) goal.blocklist: picked.contains(goal),
};
