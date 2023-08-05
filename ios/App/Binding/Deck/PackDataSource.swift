//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2021 Blocka AB. All rights reserved.
//
//  @author Karol Gusak
//

import Foundation

class PackDataSource {

    let packs = [
        Pack.mocked(id: "oisd", tags: [Pack.recommended, Pack.official, "adblocking", "tracking", "privacy", "phishing", "security"],
            title: "OISD",
            slugline: "A good general purpose blocklist",
            description: "Blocks ads, phishing, malware, spyware, ransomware, scam, telemetry, analytics, tracking (where not needed for proper functionality). Should not interfere with normal apps and services.",
            creditName: "sjhgvr",
            creditUrl: "https://go.blokada.org/oisd",
            configs: ["small", "big", "nsfw", "light"]
        ),

        Pack.mocked(id: "stevenblack", tags: [Pack.official, "adblocking", "tracking", "privacy", "porn", "social", "fake news", "gambling"],
            title: "Steven Black",
            slugline: "Popular for adblocking",
            description: "Consolidating and Extending hosts files from several well-curated sources. You can optionally pick extensions to block Porn, Social Media, and other categories.",
            creditName: "Steven Black",
            creditUrl: "https://github.com/StevenBlack/hosts",
            configs: ["unified", "fake news", "adult", "social", "gambling"]
        ),

        Pack.mocked(id: "goodbyeads", tags: [Pack.recommended, Pack.official, "adblocking", "tracking", "privacy", "youtube"],
            title: "Goodbye ads",
            slugline: "Alternative blocklist with advanced features",
            description: "A blocklist with unique extensions to choose from. Be aware it is more aggressive, and may break apps or sites. It blocks graph.facebook.com and mqtt-mini.facebook.com. You may consider whitelisting them in the Activity section, in case you experience problems with facebook apps.",
            creditName: "Jerryn70",
            creditUrl: "https://github.com/jerryn70/Goodbyeads",
            configs: ["standard", "youtube", "spotify"]
        ),

        Pack.mocked(id: "adaway", tags: [Pack.official, "adblocking"],
           title: "AdAway",
           slugline: "Adblocking for your mobile device",
           description: "A special blocklist containing mobile ad providers.",
           creditName: "AdAway Team",
           creditUrl: "https://github.com/AdAway/AdAway",
           configs: ["standard"]
        ),

        Pack.mocked(id: "phishingarmy", tags: [Pack.recommended, Pack.official, "phishing", "security"],
            title: "Phishing Army",
            slugline: "protects against cyber attacks",
            description: "A blocklist to filter phishing websites. phishing is a malpractice based on redirecting to fake websites, which look exactly like the original ones, in order to trick visitors, and steal sensitive information. Installing this blocklist will help you prevent such situations.",
            creditName: "Andrea Draghetti",
            creditUrl: "https://phishing.army/index.html",
            configs: ["standard", "extended"]
        ),

        Pack.mocked(id: "ddgtrackerradar", tags: [Pack.recommended, Pack.official, "tracking", "privacy"],
            title: "DuckDuckGo Tracker Radar",
            slugline: "A new and upcoming tracker database",
            description: "DuckDuckGo Tracker Radar is a best-in-class data set about trackers that is automatically generated and maintained through continuous crawling and analysis. See the author information for details.",
            creditName: "DuckDuckGo",
            creditUrl: "https://go.blokada.org/ddgtrackerradar",
            configs: ["standard"]
        ),

        Pack.mocked(id: "blacklist", tags: [Pack.official, "adblocking", "tracking", "privacy"],
            title: "Blacklist",
            slugline: "Curated blocklist to block trackers and advertisements",
            description: "This is a curated and well-maintained blocklist to block ads, tracking, and more! Updated regularly.",
            creditName: "anudeepND",
            creditUrl: "https://github.com/anudeepND/blacklist",
            configs: ["adservers", "facebook"]
        ),

        Pack.mocked(id: "developerdan", tags: [Pack.official, "adblocking", "tracking", "privacy", "social"],
            title: "Developer Dan's Hosts",
            slugline: "A blocklist for ads and tracking, updated regularly",
            description: "This is a good choice as the primary blocklist. It's well balanced, medium size, and frequently updated.",
            creditName: "Daniel White",
            creditUrl: "https://go.blokada.org/developerdan",
            configs: ["ads and tracking", "facebook", "amp", "hate and junk"]
        ),

        Pack.mocked(id: "blocklist", tags: [Pack.official, "adblocking", "tracking", "privacy", "social", "youtube"],
            title: "The Block List project",
            slugline: "A collection of blocklists for various use cases.",
            description: "These lists were created because the founder of the project wanted something with a little more control over what is being blocked.",
            creditName: "blocklistproject",
            creditUrl: "https://go.blokada.org/blocklistproject",
            configs: ["ads", "facebook", "malware", "phishing", "tracking", "youtube"]
        ),

        Pack.mocked(id: "spam404", tags: [Pack.recommended, Pack.official, "privacy", "phishing", "security"],
            title: "Spam404",
            slugline: "A blocklist based on spam reports",
            description: "Spam404 is a service that helps online companies with content monitoring, penetration testing and brand protection. This list is based on the reports received from companies.",
            creditName: "spam404",
            creditUrl: "https://go.blokada.org/spam404",
            configs: ["standard"]
        ),

        Pack.mocked(id: "hblock", tags: [Pack.official, "adblocking", "tracking", "phishing", "security"],
            title: "hBlock",
            slugline: "A comprehensive lists to block ads and tracking",
            description: "hBlock is a list with domains that serve ads, tracking scripts and malware. It prevents your device from connecting to them.",
            creditName: "hBlock",
            creditUrl: "https://go.blokada.org/hblock",
            configs: ["standard"]
        ),

        Pack.mocked(id: "cpbl", tags: [Pack.official, "adblocking", "tracking", "phishing", "security"],
            title: "Combined Privacy Block Lists",
            slugline: "A general purpose, medium weight list",
            description: "This list blocks malicious and harmfully deceptive content, like advertising, tracking, telemetry, scam, and malware servers. This list does not block porn, social media, or so-called fake news domains. CPBL aims to provide block lists that offer comprehensive protection, while remaining reasonable in size and scope.",
            creditName: "bongochong",
            creditUrl: "https://go.blokada.org/cpbl",
            configs: ["standard", "mini"]
        ),

        Pack.mocked(id: "danpollock", tags: [Pack.official, "adblocking", "tracking"],
            title: "Dan Pollock's Hosts",
            slugline: "A reasonably balanced ad blocking hosts file",
            description: "This is a well known, general purpose blocklist of small size, updated regularly.",
            creditName: "Dan Pollock",
            creditUrl: "https://go.blokada.org/danpollock",
            configs: ["standard"]
        ),

        Pack.mocked(id: "urlhaus", tags: [Pack.recommended, Pack.official, "security"],
            title: "URLhaus",
            slugline: "A blocklist based on malware database",
            description: "A blocklist of malicious websites that are being used for malware distribution, based on urlhaus.abuse.ch.",
            creditName: "curben",
            creditUrl: "https://go.blokada.org/urlhaus",
            configs: ["standard"]
        ),

        Pack.mocked(id: "1hosts", tags: [Pack.official, "adblocking", "tracking"],
            title: "1Hosts",
            slugline: "A blocklist for ads and tracking, updated regularly",
            description: "protect your data & eyeballs from being auctioned to the highest bidder. Please choose Light configuration first. If it is not good enough for you, try pro instead.",
            creditName: "badmojr",
            creditUrl: "https://go.blokada.org/1hosts",
            configs: ["lite (wildcards)", "pro (wildcards)", "xtra (wildcards)"]
        ),

        Pack.mocked(id: "d3host", tags: [Pack.official, "adblocking", "tracking"],
            title: "d3Host",
            slugline: "A blocklist from the maker of the adblocker test",
            description: "This is the official blocklist from d3ward, the maker of the popular adblocker testing website. It is meant to achieve 100% score in the test. Keep in mind, this is a minimum list. You may want to use it together with another blocklist activated. If you wish to perform the test, just visit go.blokada.org/test",
            creditName: "d3ward",
            creditUrl: "https://go.blokada.org/d3host",
            configs: ["standard"]
        ),

        // Meta packs for the Family flavor

        Pack.mocked(id: "meta_safe_search", tags: [Pack.recommended],
                    title: "Safe search",
                    slugline: "Secure Online Browsing",
                    description: "Enable safe search to filter out inappropriate search results in search engines, also provides the option to block unsupported search engines that cannot be filtered.",
                    creditName: "Various authors",
                    creditUrl: "https://blokada.org",
                    configs: ["block unsupported"]
                ),

        Pack.mocked(id: "meta_ads", tags: ["adblocking", "tracking"],
                    title: "Ads",
                    slugline: "Blocks advertisements and tracking",
                    description: "Eliminates intrusive advertisements and web tracking. Enhances browsing speed and safeguards user privacy.",
                    creditName: "Various authors",
                    creditUrl: "https://blokada.org",
                    configs: ["standard", "restrictive"]
                ),

        Pack.mocked(id: "meta_malware", tags: ["malware", "phishing", "spam"],
                    title: "Malware",
                    slugline: "Protects against malicious software",
                    description: "Defends against malicious software and harmful websites. Provides a secure shield against a spectrum of cyber threats.",
                    creditName: "Various authors",
                    creditUrl: "https://blokada.org",
                    configs: ["standard"]
                ),

        Pack.mocked(id: "meta_adult", tags: [Pack.recommended],
                    title: "Adult Content",
                    slugline: "Blocks adult and pornographic content",
                    description: "This filter targets adult content for a safer online experience. It shields users from explicit materials and potential risks.",
                    creditName: "Various authors",
                    creditUrl: "https://blokada.org",
                    configs: ["porn"]
                ),

        Pack.mocked(id: "meta_dating", tags: ["dating"],
                    title: "Dating",
                    slugline: "Blocks dating and relationship-seeking websites",
                    description: "Designed to restrict online dating platforms. It offers protection against potential distractions and unwanted interactions.",
                    creditName: "Various authors",
                    creditUrl: "https://blokada.org",
                    configs: ["dating"]
                ),

        Pack.mocked(id: "meta_gambling", tags: ["gambling"],
                    title: "Gambling",
                    slugline: "Blocks gambling-related content and websites",
                    description: "Denies access to gambling platforms and content. Helps in preventing addiction and ensuring financial safety.",
                    creditName: "Various authors",
                    creditUrl: "https://blokada.org",
                    configs: ["standard"]
                ),
    
        Pack.mocked(id: "meta_piracy", tags: ["piracy", "torrent", "streaming"],
                    title: "Piracy",
                    slugline: "Blocks piracy websites and related content",
                    description: "Blocks unauthorized piracy sites and related platforms. Safeguards intellectual property and reduces harmful download risks.",
                    creditName: "Various authors",
                    creditUrl: "https://blokada.org",
                    configs: ["file hosting", "torrent", "streaming"]
                ),
        
        Pack.mocked(id: "meta_videostreaming", tags: ["streaming"],
                    title: "Video streaming",
                    slugline: "Blocks popular video streaming platforms",
                    description: "Curbs access to top video streaming services. Crafted for users wanting to manage viewing habits and save bandwidth.",
                    creditName: "Various authors",
                    creditUrl: "https://blokada.org",
                    configs: ["standard"]
                ),

        Pack.mocked(id: "meta_apps_streaming", tags: ["apps", "streaming"],
                    title: "Streaming apps",
                    slugline: "Blocks streaming apps and related content",
                    description: "Features a curated selection of popular streaming apps. Allows granular control over media consumption.",
                    creditName: "Various authors",
                    creditUrl: "https://blokada.org",
                    configs: ["disney plus", "hbo max", "hulu", "netflix", "primevideo", "youtube"]
                ),

        Pack.mocked(id: "meta_social", tags: ["social", "facebook"],
                    title: "Social media",
                    slugline: "Restricts access to social networking platforms",
                    description: "Limits access to various social media platforms. Ideal for enhancing work focus and moderating children's usage.",
                    creditName: "Various authors",
                    creditUrl: "https://blokada.org",
                    configs: ["social networks", "facebook", "instagram", "reddit", "snapchat", "tiktok", "twitter"]
                ),

        Pack.mocked(id: "meta_apps_chat", tags: ["apps", "chat"],
                    title: "Chat apps",
                    slugline: "Restricts popular messaging and chat applications",
                    description: "This shield is designed to block widely-used messaging and chat apps. Perfect for those wanting to control their communication channels.",
                    creditName: "Various authors",
                    creditUrl: "https://blokada.org",
                    configs: ["discord", "messenger", "signal", "telegram"]
                ),

        Pack.mocked(id: "meta_gaming", tags: ["gaming"],
                    title: "Gaming",
                    slugline: "Blocks gaming platforms and related content",
                    description: "Restricts online gaming sites and related distractions. Designed for users wanting a balanced digital lifestyle.",
                    creditName: "Various authors",
                    creditUrl: "https://blokada.org",
                    configs: ["standard"]
                ),

        Pack.mocked(id: "meta_apps_games", tags: ["apps", "games"],
                    title: "Games",
                    slugline: "Restricts access to popular games",
                    description: "Showcases top gaming applications. Ideal for users desiring precise game access control.",
                    creditName: "Various authors",
                    creditUrl: "https://blokada.org",
                    configs: ["fortnite", "league of legends", "minecraft", "roblox", "steam", "twitch"]
                ),

        Pack.mocked(id: "meta_apps_ecommerce", tags: ["apps", "e-commerce"],
                    title: "Online shopping apps",
                    slugline: "Blocks leading e-commerce and shopping applications",
                    description: "This shield prevents access to the common shopping apps. It aids users in curbing impulse purchases or distractions.",
                    creditName: "Various authors",
                    creditUrl: "https://blokada.org",
                    configs: ["amazon", "ebay"]
                ),

        Pack.mocked(id: "meta_apps_other", tags: ["apps", "other"],
                    title: "Miscellaneous apps",
                    slugline: "A selection of various popular applications",
                    description: "This shield provides a list of popular apps of various type. It's created for users aiming for a more comprehensive app control.",
                    creditName: "Various authors",
                    creditUrl: "https://blokada.org",
                    configs: ["9gag", "chat gpt", "imgur", "pinterest", "tinder"]
                ),
    ]

    let version = 36
    
}
