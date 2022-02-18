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
            configs: ["Light"]
        )
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/oisd/light/hosts.txt", applyFor: "Light")),

        Pack.mocked(id: "energized", tags: [Pack.official, "adblocking", "tracking", "privacy", "porn", "social", "regional"],
            title: "Energized",
            slugline: "Ads and trackers blocking list",
            description: "This Energized System is designed for Unix-like systems, gets a list of domains that serve ads, tracking scripts and malware from multiple reputable sources and creates a hosts file that prevents your system from connecting to them. Beware, installing \"Social\" configuration may make your social apps, like Messenger, misbehave.",
            creditName: "Team Boltz",
            creditUrl: "https://energized.pro/",
            configs: ["Spark", "Blu", "Basic", "Adult", "Regional", "Social", "Ultimate"]
        )
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/energized/spark/hosts.txt", applyFor: "Spark"))
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/energized/blu/hosts.txt", applyFor: "Blu"))
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/energized/basic/hosts.txt", applyFor: "Basic"))
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/energized/adult/hosts.txt", applyFor: "Adult"))
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/energized/regional/hosts.txt", applyFor: "Regional"))
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/energized/social/hosts.txt", applyFor: "Social"))
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/energized/ultimate/hosts.txt", applyFor: "Ultimate")),

        Pack.mocked(id: "stevenblack", tags: [Pack.official, "adblocking", "tracking", "privacy", "porn", "social", "fake news", "gambling"],
            title: "Steven Black",
            slugline: "Popular for adblocking",
            description: "Consolidating and Extending hosts files from several well-curated sources. You can optionally pick extensions to block Porn, Social Media, and other categories.",
            creditName: "Steven Black",
            creditUrl: "https://github.com/StevenBlack/hosts",
            configs: ["Unified", "Fake news", "Adult", "Social", "Gambling"]
        )
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/stevenblack/unified/hosts.txt", applyFor: "Unified"))
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/stevenblack/fakenews/hosts.txt", applyFor: "Fake news"))
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/stevenblack/adult/hosts.txt", applyFor: "Adult"))
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/stevenblack/social/hosts.txt", applyFor: "Social"))
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/stevenblack/gambling/hosts.txt", applyFor: "Gambling")),

        Pack.mocked(id: "goodbyeads", tags: [Pack.recommended, Pack.official, "adblocking", "tracking", "privacy", "youtube"],
            title: "Goodbye Ads",
            slugline: "Alternative blocklist with advanced features",
            description: "A blocklist with unique extensions to choose from. Be aware it is more aggressive, and may break apps or sites. It blocks graph.facebook.com and mqtt-mini.facebook.com. You may consider whitelisting them in the Activity section, in case you experience problems with Facebook apps.",
            creditName: "Jerryn70",
            creditUrl: "https://github.com/jerryn70/GoodbyeAds",
            configs: ["Standard", "Youtube", "Spotify"]
        )
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/goodbyeads/standard/hosts.txt", applyFor: "Standard"))
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/goodbyeads/youtube/hosts.txt", applyFor: "Youtube"))
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/goodbyeads/spotify/hosts.txt", applyFor: "Spotify")),

        Pack.mocked(id: "adaway", tags: [Pack.official, "adblocking"],
               title: "AdAway",
               slugline: "Adblocking for your mobile device",
               description: "A special blocklist containing mobile ad providers.",
               creditName: "AdAway Team",
               creditUrl: "https://github.com/AdAway/AdAway",
               configs: ["Standard"]
           )
               .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/adaway/standard/hosts.txt", applyFor: "Standard")),

        Pack.mocked(id: "phishingarmy", tags: [Pack.recommended, Pack.official, "phishing", "security"],
            title: "Phishing Army",
            slugline: "Protects against cyber attacks",
            description: "A blocklist to filter phishing websites. Phishing is a malpractice based on redirecting to fake websites, which look exactly like the original ones, in order to trick visitors, and steal sensitive information. Installing this blocklist will help you prevent such situations.",
            creditName: "Andrea Draghetti",
            creditUrl: "https://phishing.army/index.html",
            configs: ["Standard", "Extended"]
        )
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/phishingarmy/standard/hosts.txt", applyFor: "Standard"))
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/phishingarmy/extended/hosts.txt", applyFor: "Extended")),

        Pack.mocked(id: "ddgtrackerradar", tags: [Pack.recommended, Pack.official, "tracking", "privacy"],
            title: "DuckDuckGo Tracker Radar",
            slugline: "A new and upcoming tracker database",
            description: "DuckDuckGo Tracker Radar is a best-in-class data set about trackers that is automatically generated and maintained through continuous crawling and analysis. See the author information for details.",
            creditName: "DuckDuckGo",
            creditUrl: "https://go.blokada.org/ddgtrackerradar",
            configs: ["Standard"]
        )
            .withSource(PackSource.new(url: "https://blokada.org/blocklists/ddgtrackerradar/standard/hosts.txt", applyFor: "Standard")),

        Pack.mocked(id: "blacklist", tags: [Pack.official, "adblocking", "tracking", "privacy"],
            title: "Blacklist",
            slugline: "Curated blocklist to block trackers and advertisements",
            description: "This is a curated and well-maintained blocklist to block ads, tracking, and more! Updated regularly.",
            creditName: "anudeepND",
            creditUrl: "https://github.com/anudeepND/blacklist",
            configs: ["Adservers", "Facebook"]
        )
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/blacklist/adservers/hosts.txt", applyFor: "Adservers"))
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/blacklist/facebook/hosts.txt", applyFor: "Facebook")),

        Pack.mocked(id: "developerdan", tags: [Pack.official, "adblocking", "tracking", "privacy", "social"],
            title: "Developer Dan's Hosts",
            slugline: "A blocklist for ads and tracking, updated regularly",
            description: "This is a good choice as the primary blocklist. It's well balanced, medium size, and frequently updated.",
            creditName: "Daniel White",
            creditUrl: "https://go.blokada.org/developerdan",
            configs: ["Ads and tracking", "Facebook", "Amp", "Hate and junk"]
        )
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/developerdan/ads/hosts.txt", applyFor: "Ads and tracking"))
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/developerdan/facebook/hosts.txt", applyFor: "Facebook"))
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/developerdan/amp/hosts.txt", applyFor: "Amp"))
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/developerdan/junk/hosts.txt", applyFor: "Hate and junk")),

        Pack.mocked(id: "blocklist", tags: [Pack.official, "adblocking", "tracking", "privacy", "social", "youtube"],
            title: "The Block List Project",
            slugline: "A collection of blocklists for various use cases.",
            description: "These lists were created because the founder of the project wanted something with a little more control over what is being blocked.",
            creditName: "blocklistproject",
            creditUrl: "https://go.blokada.org/blocklistproject",
            configs: ["Ads", "Facebook", "Malware", "Phishing", "Tracking", "Youtube"]
        )
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/blocklist/ads/hosts.txt", applyFor: "Ads"))
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/blocklist/facebook/hosts.txt", applyFor: "Facebook"))
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/blocklist/malware/hosts.txt", applyFor: "Malware"))
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/blocklist/phishing/hosts.txt", applyFor: "Phishing"))
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/blocklist/tracking/hosts.txt", applyFor: "Tracking"))
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/blocklist/youtube/hosts.txt", applyFor: "Youtube")),

        Pack.mocked(id: "spam404", tags: [Pack.recommended, Pack.official, "privacy", "phishing", "security"],
            title: "Spam404",
            slugline: "A blocklist based on spam reports",
            description: "Spam404 is a service that helps online companies with content monitoring, penetration testing and brand protection. This list is based on the reports received from companies.",
            creditName: "spam404",
            creditUrl: "https://go.blokada.org/spam404",
            configs: ["Standard"]
        )
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/spam404/standard/hosts.txt", applyFor: "Standard")),

        Pack.mocked(id: "hblock", tags: [Pack.official, "adblocking", "tracking", "phishing", "security"],
            title: "hBlock",
            slugline: "A comprehensive lists to block ads and tracking",
            description: "hBlock is a list with domains that serve ads, tracking scripts and malware. It prevents your device from connecting to them.",
            creditName: "hBlock",
            creditUrl: "https://go.blokada.org/hblock",
            configs: ["Standard"]
        )
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/hblock/standard/hosts.txt", applyFor: "Standard")),

        Pack.mocked(id: "cpbl", tags: [Pack.official, "adblocking", "tracking", "phishing", "security"],
            title: "Combined Privacy Block Lists",
            slugline: "A general purpose, medium weight list",
            description: "This list blocks malicious and harmfully deceptive content, like advertising, tracking, telemetry, scam, and malware servers. This list does not block porn, social media, or so-called fake news domains. CPBL aims to provide block lists that offer comprehensive protection, while remaining reasonable in size and scope.",
            creditName: "bongochong",
            creditUrl: "https://go.blokada.org/cpbl",
            configs: ["Standard", "Mini"]
        )
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/cpbl/standard/hosts.txt", applyFor: "Standard"))
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/cpbl/mini/hosts.txt", applyFor: "Mini")),

        Pack.mocked(id: "danpollock", tags: [Pack.official, "adblocking", "tracking"],
            title: "Dan Pollock's Hosts",
            slugline: "A reasonably balanced ad blocking hosts file",
            description: "This is a well known, general purpose blocklist of small size, updated regularly.",
            creditName: "Dan Pollock",
            creditUrl: "https://go.blokada.org/danpollock",
            configs: ["Standard"]
        )
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/danpollock/standard/hosts.txt", applyFor: "Standard")),

        Pack.mocked(id: "urlhaus", tags: [Pack.recommended, Pack.official, "security"],
            title: "URLhaus",
            slugline: "A blocklist based on malware database",
            description: "A blocklist of malicious websites that are being used for malware distribution, based on urlhaus.abuse.ch.",
            creditName: "curben",
            creditUrl: "https://go.blokada.org/urlhaus",
            configs: ["Standard"]
        )
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/urlhaus/standard/hosts.txt", applyFor: "Standard")),

        Pack.mocked(id: "1hosts", tags: [Pack.official, "adblocking", "tracking"],
            title: "1Hosts",
            slugline: "A blocklist for ads and tracking, updated regularly",
            description: "Protect your data & eyeballs from being auctioned to the highest bidder. Please choose Light configuration first. If it is not good enough for you, try Pro instead.",
            creditName: "badmojr",
            creditUrl: "https://go.blokada.org/1hosts",
            configs: ["Lite", "Pro"]
        )
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/1hosts/lite/hosts.txt", applyFor: "Lite"))
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/1hosts/pro/hosts.txt", applyFor: "Pro")),

        Pack.mocked(id: "d3host", tags: [Pack.official, "adblocking", "tracking"],
            title: "d3Host",
            slugline: "A blocklist from the maker of the adblocker test",
            description: "This is the official blocklist from d3ward, the maker of the popular adblocker testing website. It is meant to achieve 100% score in the test. Keep in mind, this is a minimum list. You may want to use it together with another blocklist activated. If you wish to perform the test, just visit go.blokada.org/test",
            creditName: "d3ward",
            creditUrl: "https://go.blokada.org/d3host",
            configs: ["Standard"]
        )
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/d3host/standard/hosts.txt", applyFor: "Standard")),

    ]

    let version = 31
    
}
