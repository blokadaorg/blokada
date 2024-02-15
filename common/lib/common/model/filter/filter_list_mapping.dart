part of '../../model.dart';

/// Defines a mapping between Filters used by the app, and the blocklists used
/// by the api. This layer of abstraction is needed for the app to be able to
/// put together different Filters using various sets of lists, depending on app
/// flavor.

List<Filter> getKnownFilters(Act act) {
  if (act.isFamily()) {
    return _family;
  } else if (act.getPlatform() == Platform.ios) {
    return _v6iOS;
  } else {
    return _v6Android;
  }
}

final _v6iOS = [
  Filter("oisd", [
    Option("small", FilterAction.list, [
      "oisd/light"
    ]), // change on oisd/small once backend doesnt force the former as default
    Option("big", FilterAction.list, ["oisd/big"]),
    Option("nsfw", FilterAction.list, ["oisd/nsfw"]),
  ]),
  Filter("stevenblack", [
    Option("unified", FilterAction.list, ["stevenblack/unified"]),
    Option("fake news", FilterAction.list, ["stevenblack/fake news"]),
    Option("adult", FilterAction.list, ["stevenblack/adult"]),
    Option("social", FilterAction.list, ["stevenblack/social"]),
    Option("gambling", FilterAction.list, ["stevenblack/gambling"]),
  ]),
  Filter("goodbyeads", [
    Option("standard", FilterAction.list, ["goodbyeads/standard"]),
    Option("youtube", FilterAction.list, ["goodbyeads/youtube"]),
    Option("spotify", FilterAction.list, ["goodbyeads/spotify"]),
  ]),
  Filter("adaway", [
    Option("standard", FilterAction.list, ["adaway/standard"]),
  ]),
  Filter("phishingarmy", [
    Option("standard", FilterAction.list, ["phishingarmy/standard"]),
    Option("extended", FilterAction.list, ["phishingarmy/extended"]),
  ]),
  Filter("ddgtrackerradar", [
    Option("standard", FilterAction.list, ["ddgtrackerradar/standard"]),
  ]),
  Filter("blacklist", [
    Option("adservers", FilterAction.list, ["blacklist/adservers"]),
    Option("facebook", FilterAction.list, ["blacklist/facebook"]),
  ]),
  Filter("developerdan", [
    Option("ads and tracking", FilterAction.list,
        ["developerdan/ads and tracking"]),
    Option("facebook", FilterAction.list, ["developerdan/facebook"]),
    Option("amp", FilterAction.list, ["developerdan/amp"]),
    Option("hate and junk", FilterAction.list, ["developerdan/hate and junk"]),
  ]),
  Filter("blocklist", [
    Option("ads", FilterAction.list, ["blocklist/ads"]),
    Option("facebook", FilterAction.list, ["blocklist/facebook"]),
    Option("malware", FilterAction.list, ["blocklist/malware"]),
    Option("phishing", FilterAction.list, ["blocklist/phishing"]),
    Option("tracking", FilterAction.list, ["blocklist/tracking"]),
    Option("youtube", FilterAction.list, ["blocklist/youtube"]),
  ]),
  Filter("spam404", [
    Option("standard", FilterAction.list, ["spam404/standard"]),
  ]),
  Filter("hblock", [
    Option("standard", FilterAction.list, ["hblock/standard"]),
  ]),
  Filter("cpbl", [
    Option("standard", FilterAction.list, ["cpbl/standard"]),
    Option("mini", FilterAction.list, ["cpbl/mini"]),
  ]),
  Filter("danpollock", [
    Option("standard", FilterAction.list, ["danpollock/standard"]),
  ]),
  Filter("urlhaus", [
    Option("standard", FilterAction.list, ["urlhaus/standard"]),
  ]),
  Filter("1hosts", [
    Option("lite", FilterAction.list, ["1hosts/lite (wildcards)"]),
    Option("pro", FilterAction.list, ["1hosts/pro (wildcards)"]),
    Option("xtra", FilterAction.list, ["1hosts/xtra (wildcards)"]),
  ]),
  Filter("d3host", [
    Option("standard", FilterAction.list, ["d3host/standard"]),
  ]),
];

final _v6Android = [
  Filter("oisd", [
    Option("small", FilterAction.list, [
      "oisd/light"
    ]), // change on oisd/small once backend doesnt force the former as default
    Option("big", FilterAction.list, ["oisd/big"]),
    Option("nsfw", FilterAction.list, ["oisd/nsfw"]),
  ]),
  Filter("stevenblack", [
    Option("unified", FilterAction.list, ["stevenblack/unified"]),
    Option("fake news", FilterAction.list, ["stevenblack/fake news"]),
    Option("adult", FilterAction.list, ["stevenblack/adult"]),
    Option("social", FilterAction.list, ["stevenblack/social"]),
    Option("gambling", FilterAction.list, ["stevenblack/gambling"]),
  ]),
  Filter("goodbyeads", [
    Option("standard", FilterAction.list, ["goodbyeads/standard"]),
    Option("samsung", FilterAction.list, ["goodbyeads/samsung"]),
    Option("xiaomi", FilterAction.list, ["goodbyeads/xiaomi"]),
    Option("spotify", FilterAction.list, ["goodbyeads/spotify"]),
    Option("youtube", FilterAction.list, ["goodbyeads/youtube"]),
  ]),
  Filter("adaway", [
    Option("standard", FilterAction.list, ["adaway/standard"]),
  ]),
  Filter("phishingarmy", [
    Option("standard", FilterAction.list, ["phishingarmy/standard"]),
    Option("extended", FilterAction.list, ["phishingarmy/extended"]),
  ]),
  Filter("ddgtrackerradar", [
    Option("standard", FilterAction.list, ["ddgtrackerradar/standard"]),
  ]),
  Filter("blacklist", [
    Option("adservers", FilterAction.list, ["blacklist/adservers"]),
    Option("facebook", FilterAction.list, ["blacklist/facebook"]),
  ]),
  Filter("developerdan", [
    Option("ads and tracking", FilterAction.list,
        ["developerdan/ads and tracking"]),
    Option("facebook", FilterAction.list, ["developerdan/facebook"]),
    Option("amp", FilterAction.list, ["developerdan/amp"]),
    Option("hate and junk", FilterAction.list, ["developerdan/hate and junk"]),
  ]),
  Filter("blocklist", [
    Option("ads", FilterAction.list, ["blocklist/ads"]),
    Option("facebook", FilterAction.list, ["blocklist/facebook"]),
    Option("malware", FilterAction.list, ["blocklist/malware"]),
    Option("phishing", FilterAction.list, ["blocklist/phishing"]),
    Option("tracking", FilterAction.list, ["blocklist/tracking"]),
    Option("youtube", FilterAction.list, ["blocklist/youtube"]),
  ]),
  Filter("spam404", [
    Option("standard", FilterAction.list, ["spam404/standard"]),
  ]),
  Filter("hblock", [
    Option("standard", FilterAction.list, ["hblock/standard"]),
  ]),
  Filter("cpbl", [
    Option("standard", FilterAction.list, ["cpbl/standard"]),
    Option("mini", FilterAction.list, ["cpbl/mini"]),
  ]),
  Filter("danpollock", [
    Option("standard", FilterAction.list, ["danpollock/standard"]),
  ]),
  Filter("urlhaus", [
    Option("standard", FilterAction.list, ["urlhaus/standard"]),
  ]),
  Filter("1hosts", [
    Option("lite", FilterAction.list, ["1hosts/lite (wildcards)"]),
    Option("pro", FilterAction.list, ["1hosts/pro (wildcards)"]),
    Option("xtra", FilterAction.list, ["1hosts/xtra (wildcards)"]),
  ]),
  Filter("d3host", [
    Option("standard", FilterAction.list, ["d3host/standard"]),
  ]),
];

final _family = [
  Filter("meta_safe_search", [
    Option(
        "safe search", FilterAction.config, [FilterConfigKey.safeSearch.name]),
    Option("block unsupported", FilterAction.list, ["safesearch/nosafesearch"]),
  ]),
  Filter("meta_ads", [
    Option("standard", FilterAction.list, [
      "oisd/small",
      "goodbyeads/standard",
      "adaway/standard",
      "1hosts/lite (wildcards)",
      "d3host/standard",
    ]),
    Option("restrictive", FilterAction.list, [
      "oisd/big",
      "ddgtrackerradar/standard",
      "1hosts/xtra (wildcards)",
      // Those below I'm not sure how to treat
      "cpbl/standard",
      "blacklist/adservers",
      "developerdan/ads and tracking",
      "blocklist/ads",
      "blocklist/tracking",
      "hblock/standard",
      "danpollock/standard",
    ]),
  ]),
  Filter("meta_malware", [
    Option("standard", FilterAction.list, [
      "phishingarmy/standard",
      "phishingarmy/extended",
      "blocklist/malware",
      "blocklist/phishing",
      "spam404/standard",
      "urlhaus/standard",
    ]),
  ]),
  Filter("meta_adult", [
    Option("porn", FilterAction.list, [
      "stevenblack/adult",
      "sinfonietta/porn",
      "tiuxo/porn",
      "mhxion/porn",
    ]),
  ]),
  Filter("meta_dating", [
    Option("standard", FilterAction.list, [
      "ut1/dating",
    ]),
  ]),
  Filter("meta_gambling", [
    Option("standard", FilterAction.list, [
      "stevenblack/gambling",
      "ut1/gambling",
      "sinfonietta/gambling",
    ]),
  ]),
  Filter("meta_piracy", [
    Option("file hosting", FilterAction.list, [
      "ut1/warez",
      "ndnspiracy/file hosting",
      "ndnspiracy/proxies",
      "ndnspiracy/usenet",
      "ndnspiracy/warez",
    ]),
    Option("torrent", FilterAction.list, [
      "ndnspiracy/dht bootstrap nodes",
      "ndnspiracy/torrent clients",
      "ndnspiracy/torrent trackers",
      "ndnspiracy/torrent websites",
    ]),
    Option("streaming", FilterAction.list, [
      "ndnspiracy/streaming audio",
      "ndnspiracy/streaming video",
    ]),
  ]),
  Filter("meta_videostreaming", [
    Option("standard", FilterAction.list, [
      "ndnspiracy/streaming video",
    ]),
  ]),
  Filter("meta_apps_streaming", [
    Option("disney plus", FilterAction.list, [
      "ndnsapps/disneyplus",
    ]),
    Option("hbo max", FilterAction.list, [
      "ndnsapps/hbomax",
    ]),
    Option("hulu", FilterAction.list, [
      "ndnsapps/hulu",
    ]),
    Option("netflix", FilterAction.list, [
      "ndnsapps/netflix",
    ]),
    Option("primevideo", FilterAction.list, [
      "ndnsapps/primevideo",
    ]),
    Option("youtube", FilterAction.list, [
      "ndnsapps/youtube",
    ]),
  ]),
  Filter("meta_social", [
    Option("social networks", FilterAction.list, [
      "stevenblack/social",
      "ut1/social",
      "sinfonietta/social",
    ]),
    Option("facebook", FilterAction.list, [
      "blacklist/facebook",
      "developerdan/facebook",
      "blocklist/facebook",
      "ndnsapps/facebook",
    ]),
    Option("instagram", FilterAction.list, [
      "ndnsapps/instagram",
    ]),
    Option("reddit", FilterAction.list, [
      "ndnsapps/reddit",
    ]),
    Option("snapchat", FilterAction.list, [
      "ndnsapps/snapchat",
    ]),
    Option("tiktok", FilterAction.list, [
      "ndnsapps/tiktok",
    ]),
    Option("twitter", FilterAction.list, [
      "ndnsapps/twitter",
    ]),
  ]),
  Filter("meta_apps_chat", [
    Option("discord", FilterAction.list, [
      "ndnsapps/discord",
    ]),
    Option("messenger", FilterAction.list, [
      "ndnsapps/messenger",
    ]),
    Option("signal", FilterAction.list, [
      "ndnsapps/signal",
    ]),
    Option("telegram", FilterAction.list, [
      "ndnsapps/telegram",
    ]),
  ]),
  Filter("meta_gaming", [
    Option("standard", FilterAction.list, [
      "ut1/gaming",
    ]),
  ]),
  Filter("meta_apps_games", [
    Option("fortnite", FilterAction.list, [
      "ndnsapps/fortnite",
    ]),
    Option("league of legends", FilterAction.list, [
      "ndnsapps/leagueoflegends",
    ]),
    Option("minecraft", FilterAction.list, [
      "ndnsapps/minecraft",
    ]),
    Option("roblox", FilterAction.list, [
      "ndnsapps/roblox",
    ]),
    Option("steam", FilterAction.list, [
      "ndnsapps/steam",
    ]),
    Option("twitch", FilterAction.list, [
      "ndnsapps/twitch",
    ]),
  ]),
  Filter("meta_apps_commerce", [
    Option("amazon", FilterAction.list, [
      "ndnsapps/amazon",
    ]),
    Option("ebay", FilterAction.list, [
      "ndnsapps/ebay",
    ]),
  ]),
  Filter("meta_apps_other", [
    Option("9gag", FilterAction.list, [
      "ndnsapps/9gag",
    ]),
    Option("chat gpt", FilterAction.list, [
      "ndnsapps/chatgpt",
    ]),
    Option("imgur", FilterAction.list, [
      "ndnsapps/imgur",
    ]),
    Option("pinterest", FilterAction.list, [
      "ndnsapps/pinterest",
    ]),
    Option("tinder", FilterAction.list, [
      "ndnsapps/tinder",
    ]),
  ]),
];
