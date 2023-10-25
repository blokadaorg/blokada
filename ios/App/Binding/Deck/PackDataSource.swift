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
        )
    ]

    let version = 31
    
}
