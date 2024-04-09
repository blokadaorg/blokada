import '../model.dart';

final filterDecorDefaults = _v6 + _family;

final _v6 = [
  FilterDecor(
    filterName: "oisd",
    tags: [
      "recommended",
      "official",
      "adblocking",
      "tracking",
      "privacy",
      "phishing",
      "security"
    ],
    title: "OISD",
    slug: "A good general purpose blocklist",
    description:
        "Blocks ads, phishing, malware, spyware, ransomware, scam, telemetry, analytics, tracking (where not needed for proper functionality). Should not interfere with normal apps and services.",
    creditName: "sjhgvr",
    creditUrl: "https://go.blokada.org/oisd",
  ),
  FilterDecor(
    filterName: "stevenblack",
    tags: [
      "official",
      "adblocking",
      "tracking",
      "privacy",
      "porn",
      "social",
      "fake news",
      "gambling"
    ],
    title: "Steven Black",
    slug: "Popular for adblocking",
    description:
        "Consolidating and Extending hosts files from several well-curated sources. You can optionally pick extensions to block Porn, Social Media, and other categories.",
    creditName: "Steven Black",
    creditUrl: "https://github.com/StevenBlack/hosts",
  ),
  FilterDecor(
    filterName: "goodbyeads",
    tags: [
      "recommended",
      "official",
      "adblocking",
      "tracking",
      "privacy",
      "youtube"
    ],
    title: "Goodbye ads",
    slug: "Alternative blocklist with advanced features",
    description:
        "A blocklist with unique extensions to choose from. Be aware it is more aggressive, and may break apps or sites. It blocks graph.facebook.com and mqtt-mini.facebook.com. You may consider whitelisting them in the Activity section, in case you experience problems with facebook apps.",
    creditName: "Jerryn70",
    creditUrl: "https://github.com/jerryn70/Goodbyeads",
  ),
  FilterDecor(
    filterName: "adaway",
    tags: ["official", "adblocking"],
    title: "AdAway",
    slug: "Adblocking for your mobile device",
    description: "A special blocklist containing mobile ad providers.",
    creditName: "AdAway Team",
    creditUrl: "https://github.com/AdAway/AdAway",
  ),
  FilterDecor(
    filterName: "phishingarmy",
    tags: ["recommended", "official", "phishing", "security"],
    title: "Phishing Army",
    slug: "protects against cyber attacks",
    description:
        "A blocklist to filter phishing websites. phishing is a malpractice based on redirecting to fake websites, which look exactly like the original ones, in order to trick visitors, and steal sensitive information. Installing this blocklist will help you prevent such situations.",
    creditName: "Andrea Draghetti",
    creditUrl: "https://phishing.army/index.html",
  ),
  FilterDecor(
    filterName: "ddgtrackerradar",
    tags: ["recommended", "official", "tracking", "privacy"],
    title: "DuckDuckGo Tracker Radar",
    slug: "A new and upcoming tracker database",
    description:
        "DuckDuckGo Tracker Radar is a best-in-class data set about trackers that is automatically generated and maintained through continuous crawling and analysis. See the author information for details.",
    creditName: "DuckDuckGo",
    creditUrl: "https://go.blokada.org/ddgtrackerradar",
  ),
  FilterDecor(
    filterName: "blacklist",
    tags: ["official", "adblocking", "tracking", "privacy"],
    title: "Blacklist",
    slug: "Curated blocklist to block trackers and advertisements",
    description:
        "This is a curated and well-maintained blocklist to block ads, tracking, and more! Updated regularly.",
    creditName: "anudeepND",
    creditUrl: "https://github.com/anudeepND/blacklist",
  ),
  FilterDecor(
    filterName: "developerdan",
    tags: ["official", "adblocking", "tracking", "privacy", "social"],
    title: "Developer Dan's Hosts",
    slug: "A blocklist for ads and tracking, updated regularly",
    description:
        "This is a good choice as the primary blocklist. It's well balanced, medium size, and frequently updated.",
    creditName: "Daniel White",
    creditUrl: "https://go.blokada.org/developerdan",
  ),
  FilterDecor(
    filterName: "blocklist",
    tags: [
      "official",
      "adblocking",
      "tracking",
      "privacy",
      "social",
      "youtube"
    ],
    title: "The Block List project",
    slug: "A collection of blocklists for various use cases.",
    description:
        "These lists were created because the founder of the project wanted something with a little more control over what is being blocked.",
    creditName: "blocklistproject",
    creditUrl: "https://go.blokada.org/blocklistproject",
  ),
  FilterDecor(
    filterName: "spam404",
    tags: ["recommended", "official", "privacy", "phishing", "security"],
    title: "Spam404",
    slug: "A blocklist based on spam reports",
    description:
        "Spam404 is a service that helps online companies with content monitoring, penetration testing and brand protection. This list is based on the reports received from companies.",
    creditName: "spam404",
    creditUrl: "https://go.blokada.org/spam404",
  ),
  FilterDecor(
    filterName: "hblock",
    tags: [
      "official",
      "adblocking",
      "tracking",
      "privacy",
      "phishing",
      "security"
    ],
    title: "hBlock",
    slug: "A comprehensive lists to block ads and tracking",
    description:
        "hBlock is a list with domains that serve ads, tracking scripts and malware. It prevents your device from connecting to them.",
    creditName: "hBlock",
    creditUrl: "https://go.blokada.org/hblock",
  ),
  FilterDecor(
    filterName: "cpbl",
    tags: [
      "official",
      "adblocking",
      "tracking",
      "privacy",
      "phishing",
      "security"
    ],
    title: "Combined Privacy Block Lists",
    slug: "A general purpose, medium weight list",
    description:
        "This list blocks malicious and harmfully deceptive content, like advertising, tracking, telemetry, scam, and malware servers. This list does not block porn, social media, or so-called fake news domains. CPBL aims to provide block lists that offer comprehensive protection, while remaining reasonable in size and scope.",
    creditName: "bongochong",
    creditUrl: "https://go.blokada.org/cpbl",
  ),
  FilterDecor(
    filterName: "danpollock",
    tags: ["official", "adblocking", "tracking"],
    title: "Dan Pollock's Hosts",
    slug: "A reasonably balanced ad blocking hosts file",
    description:
        "This is a well known, general purpose bljocklist of small size, updated regularly.",
    creditName: "Dan Pollock",
    creditUrl: "https://go.blokada.org/danpollock",
  ),
  FilterDecor(
    filterName: "urlhaus",
    tags: ["recommended", "official", "security"],
    title: "URLhaus",
    slug: "A blocklist based on malware database",
    description:
        "A blocklist of malicious websites that are being used for malware distribution, based on urlhaus.abuse.ch.",
    creditName: "curben",
    creditUrl: "https://go.blokada.org/urlhaus",
  ),
  FilterDecor(
    filterName: "1Hosts",
    tags: ["official", "adblocking", "tracking"],
    title: "1Hosts",
    slug: "A blocklist for ads and tracking, updated regularly",
    description:
        "protect your data & eyeballs from being auctioned to the highest bidder. Please choose Light configuration first. If it is not good enough for you, try pro instead.",
    creditName: "badmojr",
    creditUrl: "https://go.blokada.org/1hosts",
  ),
  FilterDecor(
    filterName: "d3host",
    tags: ["official", "adblocking", "tracking"],
    title: "d3Host",
    slug: "A blocklist from the maker of the adblocker test",
    description:
        "This is the official blocklist from d3ward, the maker of the popular adblocker testing website. It is meant to achieve 100% score in the test. Keep in mind, this is a minimum list. You may want to use it together with another blocklist activated. If you wish to perform the test, just visit go.blokada.org/test",
    creditName: "d3ward",
    creditUrl: "https://go.blokada.org/d3host",
  ),
];

final _family = [
  FilterDecor(
    filterName: "meta_safe_search",
    tags: ["recommended"],
    title: "Safe search",
    slug: "Secure Online Browsing",
    description:
        "Enable safe search to filter out inappropriate search results in search engines, also provides the option to block unsupported search engines that cannot be filtered.",
  ),
  FilterDecor(
    filterName: "meta_ads",
    tags: ["adblocking", "tracking"],
    title: "Ads",
    slug: "Blocks advertisements and tracking",
    description:
        "Eliminates intrusive advertisements and web tracking. Enhances browsing speed and safeguards user privacy.",
  ),
  FilterDecor(
    filterName: "meta_malware",
    tags: ["malware", "phishing", "spam"],
    title: "Malware",
    slug: "Protects against malicious software",
    description:
        "Defends against malicious software and harmful websites. Provides a secure shield against a spectrum of cyber threats.",
  ),
  FilterDecor(
    filterName: "meta_adult",
    tags: ["recommended"],
    title: "Adult Content",
    slug: "Blocks adult and pornographic content",
    description:
        "This filter targets adult content for a safer online experience. It shields users from explicit materials and potential risks.",
  ),
  FilterDecor(
    filterName: "meta_dating",
    tags: ["dating"],
    title: "Dating",
    slug: "Blocks dating and relationship-seeking websites",
    description:
        "Designed to restrict online dating platforms. It offers protection against potential distractions and unwanted interactions.",
  ),
  FilterDecor(
    filterName: "meta_gambling",
    tags: ["gambling"],
    title: "Gambling",
    slug: "Blocks gambling-related content and websites",
    description:
        "Denies access to gambling platforms and content. Helps in preventing addiction and ensuring financial safety.",
  ),
  FilterDecor(
    filterName: "meta_piracy",
    tags: ["piracy", "torrent", "streaming"],
    title: "Piracy",
    slug: "Blocks piracy websites and related content",
    description:
        "Blocks unauthorized piracy sites and related platforms. Safeguards intellectual property and reduces harmful download risks.",
  ),
  FilterDecor(
    filterName: "meta_videostreaming",
    tags: ["social", "facebook"],
    title: "Video streaming",
    slug: "Blocks popular video streaming platforms",
    description:
        "Curbs access to top video streaming services. Crafted for users wanting to manage viewing habits and save bandwidth.",
  ),
  FilterDecor(
    filterName: "meta_apps_streaming",
    tags: ["apps", "streaming"],
    title: "Streaming apps",
    slug: "Blocks streaming apps and related content",
    description:
        "Features a curated selection of popular streaming apps. Allows granular control over media consumption.",
  ),
  FilterDecor(
    filterName: "meta_social",
    tags: ["social", "facebook"],
    title: "Social media",
    slug: "Restricts access to social networking platforms",
    description:
        "Limits access to various social media platforms. Ideal for enhancing work focus and moderating children's usage.",
  ),
  FilterDecor(
    filterName: "meta_apps_chat",
    tags: ["apps", "chat"],
    title: "Chat apps",
    slug: "Restricts popular messaging and chat applications",
    description:
        "This shield is designed to block widely-used messaging and chat apps. Perfect for those wanting to control their communication channels.",
  ),
  FilterDecor(
    filterName: "meta_gaming",
    tags: ["gaming"],
    title: "Gaming",
    slug: "Blocks gaming platforms and related content",
    description:
        "Restricts online gaming sites and related distractions. Designed for users wanting a balanced digital lifestyle.",
  ),
  FilterDecor(
    filterName: "meta_apps_games",
    tags: ["apps", "games"],
    title: "Games",
    slug: "Restricts access to popular games",
    description:
        "Showcases top gaming applications. Ideal for users desiring precise game access control.",
  ),
  FilterDecor(
    filterName: "meta_apps_commerce",
    tags: ["apps", "e-commerce"],
    title: "Online shopping apps",
    slug: "Blocks leading e-commerce and shopping applications",
    description:
        "This shield prevents access to the common shopping apps. It aids users in curbing impulse purchases or distractions.",
  ),
  FilterDecor(
    filterName: "meta_apps_other",
    tags: ["apps", "other"],
    title: "Miscellaneous apps",
    slug: "A selection of various popular applications",
    description:
        "This shield provides a list of popular apps of various type. It's created for users aiming for a more comprehensive app control.",
  ),
];
