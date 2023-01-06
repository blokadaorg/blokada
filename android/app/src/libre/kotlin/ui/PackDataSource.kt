/*
 * This file is part of Blokada.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Copyright © 2021 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package ui

import model.*
import utils.FlavorSpecific

object PackDataSource: FlavorSpecific {

    // iOS has similar list
    fun getPacks() = listOf(
        Pack.mocked(id = "oisd", tags = listOf(Pack.recommended, Pack.official, "adblocking", "tracking", "privacy", "phishing", "security"),
            title = "OISD",
            slugline = "A good general purpose blocklist",
            description = "This universal list primarily blocks ads, and mobile app ads. Should not interfere with normal apps and services.",
            creditName = "sjhgvr",
            creditUrl = "https://oisd.nl/",
            configs = listOf("Basic (Wildcards)", "Extra (Wildcards)", "Light")
        )
            .changeStatus(config = "Basic (Wildcards)")
            .changeStatus(installed = true) // Default config. Will auto download.
            .withSource(PackSource.new(urls = listOf("https://blokada.org/mirror/v5/oisd/basic (wildcards)/hosts.txt", "https://abp.oisd.nl/basic/"), applyFor = "Basic (Wildcards)"))
            .withSource(PackSource.new(urls = listOf("https://blokada.org/mirror/v5/oisd/extra (wildcards)/hosts.txt", "https://abp.oisd.nl/extra/"), applyFor = "Extra (Wildcards)"))
            .withSource(PackSource.new(urls = listOf("https://blokada.org/mirror/v5/oisd/basic (wildcards)/hosts.txt", "https://abp.oisd.nl/basic/"), applyFor = "Light")),

    Pack.mocked(id = "energized", tags = listOf(Pack.official, "adblocking", "tracking", "privacy", "porn", "social", "regional"),
            title = "Energized",
            slugline = "Ads and trackers blocking list",
            description = "This Energized System is designed for Unix-like systems, gets a list of domains that serve ads, tracking scripts and malware from multiple reputable sources and creates a hosts file that prevents your system from connecting to them. Beware, installing \"Social\" configuration may make your social apps, like Messenger, misbehave.",
            creditName = "Team Boltz",
            creditUrl = "https://energized.pro/",
            configs = listOf("Spark", "Blu", "Basic", "Porn", "Regional", "Social", "Ultimate")
        )
            .changeStatus(config = "Blu")
            .withSource(PackSource.new(urls = listOf("https://blokada.org/mirror/v5/energized/spark/hosts.txt", "https://block.energized.pro/spark/formats/domains.txt"), applyFor = "Spark"))
            .withSource(PackSource.new(urls = listOf("https://blokada.org/mirror/v5/energized/blu/hosts.txt", "https://block.energized.pro/blu/formats/domains.txt"), applyFor = "Blu"))
            .withSource(PackSource.new(urls = listOf("https://blokada.org/mirror/v5/energized/basic/hosts.txt", "https://block.energized.pro/basic/formats/domains.txt"), applyFor = "Basic"))
            .withSource(PackSource.new(urls = listOf("https://blokada.org/mirror/v5/energized/adult/hosts.txt", "https://block.energized.pro/porn/formats/domains.txt"), applyFor = "Porn"))
            .withSource(PackSource.new(urls = listOf("https://blokada.org/mirror/v5/energized/regional/hosts.txt", "https://block.energized.pro/extensions/regional/formats/domains.txt"), applyFor = "Regional"))
            .withSource(PackSource.new(urls = listOf("https://blokada.org/mirror/v5/energized/social/hosts.txt", "https://block.energized.pro/extensions/social/formats/domains.txt"), applyFor = "Social"))
            .withSource(PackSource.new(urls = listOf("https://blokada.org/mirror/v5/energized/ultimate/hosts.txt", "https://block.energized.pro/ultimate/formats/domains.txt"), applyFor = "Ultimate")),

        Pack.mocked(id = "stevenblack", tags = listOf(Pack.official, "adblocking", "tracking", "privacy", "porn", "social", "fake news", "gambling"),
            title = "Steven Black",
            slugline = "Popular for adblocking",
            description = "Consolidating and Extending hosts files from several well-curated sources. You can optionally pick extensions to block Porn, Social Media, and other categories.",
            creditName = "Steven Black",
            creditUrl = "https://github.com/StevenBlack/hosts",
            configs = listOf("Unified", "Fake news", "Porn", "Social", "Gambling")
        )
            .changeStatus(config = "Unified")
            .withSource(PackSource.new(urls = listOf("https://blokada.org/mirror/v5/stevenblack/unified/hosts.txt", "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"), applyFor = "Unified"))
            .withSource(PackSource.new(urls = listOf("https://blokada.org/mirror/v5/stevenblack/fakenews/hosts.txt", "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews/hosts"), applyFor = "Fake news"))
            .withSource(PackSource.new(urls = listOf("https://blokada.org/mirror/v5/stevenblack/adult/hosts.txt", "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/porn/hosts"), applyFor = "Porn"))
            .withSource(PackSource.new(urls = listOf("https://blokada.org/mirror/v5/stevenblack/social/hosts.txt", "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/social/hosts"), applyFor = "Social"))
            .withSource(PackSource.new(urls = listOf("https://blokada.org/mirror/v5/stevenblack/gambling/hosts.txt", "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/gambling/hosts"), applyFor = "Gambling")),

        Pack.mocked(id = "goodbyeads", tags = listOf(Pack.recommended, Pack.official, "adblocking", "tracking", "privacy"),
            title = "Goodbye Ads",
            slugline = "Alternative blocklist with advanced features",
            description = "A blocklist with unique extensions to choose from. Be aware it is more aggressive, and may break apps or sites. It blocks graph.facebook.com and mqtt-mini.facebook.com. You may consider whitelisting them in the Activity section, in case you experience problems with Facebook apps.",
            creditName = "Jerryn70",
            creditUrl = "https://github.com/jerryn70/GoodbyeAds",
            configs = listOf("Standard", "Samsung", "Xiaomi", "Spotify")
        )
            .changeStatus(config = "Standard")
            .withSource(PackSource.new(urls = listOf("https://blokada.org/mirror/v5/goodbyeads/standard/hosts.txt", "https://raw.githubusercontent.com/jerryn70/GoodbyeAds/master/Hosts/GoodbyeAds.txt"), applyFor = "Standard"))
            .withSource(PackSource.new(urls = listOf("https://blokada.org/mirror/v5/goodbyeads/samsung/hosts.txt", "https://raw.githubusercontent.com/jerryn70/GoodbyeAds/master/Extension/GoodbyeAds-Samsung-AdBlock.txt"), applyFor = "Samsung"))
            .withSource(PackSource.new(urls = listOf("https://blokada.org/mirror/v5/goodbyeads/xiaomi/hosts.txt", "https://raw.githubusercontent.com/jerryn70/GoodbyeAds/master/Extension/GoodbyeAds-Xiaomi-Extension.txt"), applyFor = "Xiaomi"))
            .withSource(PackSource.new(urls = listOf("https://blokada.org/mirror/v5/goodbyeads/spotify/hosts.txt", "https://raw.githubusercontent.com/jerryn70/GoodbyeAds/master/Extension/GoodbyeAds-Spotify-AdBlock.txt"), applyFor = "Spotify")),

        Pack.mocked(id = "adaway", tags = listOf(Pack.official, "adblocking"),
            title = "AdAway",
            slugline = "Adblocking for your mobile device",
            description = "A special blocklist containing mobile ad providers.",
            creditName = "AdAway Team",
            creditUrl = "https://github.com/AdAway/AdAway",
            configs = listOf("Standard")
        )
            .changeStatus(config = "Standard")
            .withSource(PackSource.new(urls = listOf("https://blokada.org/mirror/v5/adaway/standard/hosts.txt", "https://adaway.org/hosts.txt"), applyFor = "Standard")),

        Pack.mocked(id = "phishingarmy", tags = listOf(Pack.recommended, Pack.official, "phishing", "security"),
            title = "Phishing Army",
            slugline = "Protects against cyber attacks",
            description = "A blocklist to filter phishing websites. Phishing is a malpractice based on redirecting to fake websites, which look exactly like the original ones, in order to trick visitors, and steal sensitive information. Installing this blocklist will help you prevent such situations.",
            creditName = "Andrea Draghetti",
            creditUrl = "https://phishing.army/index.html",
            configs = listOf("Standard", "Extended")
        )
            .changeStatus(config = "Standard")
            .withSource(PackSource.new(urls = listOf("https://blokada.org/mirror/v5/phishingarmy/standard/hosts.txt", "https://phishing.army/download/phishing_army_blocklist.txt"), applyFor = "Standard"))
            .withSource(PackSource.new(urls = listOf("https://blokada.org/mirror/v5/phishingarmy/extended/hosts.txt", "https://phishing.army/download/phishing_army_blocklist_extended.txt"), applyFor = "Extended")),

        Pack.mocked(id = "ddgtrackerradar", tags = listOf(Pack.recommended, Pack.official, "tracking", "privacy"),
            title = "DuckDuckGo Tracker Radar",
            slugline = "A new and expanding tracker database",
            description = "DuckDuckGo Tracker Radar is a best-in-class data set about trackers that is automatically generated and maintained through continuous crawling and analysis. See the author information for details.",
            creditName = "DuckDuckGo",
            creditUrl = "https://go.blokada.org/ddgtrackerradar",
            configs = listOf("Standard")
        )
            .changeStatus(config = "Standard")
            .withSource(PackSource.new(urls = listOf("https://blokada.org/mirror/v5/ddgtrackerradar/standard/hosts.txt", "https://blokada.org/blocklists/ddgtrackerradar/standard/hosts.txt"), applyFor = "Standard")),

        Pack.mocked(id = "blacklist", tags = listOf(Pack.official, "adblocking", "tracking", "privacy"),
            title = "Blacklist",
            slugline = "Curated blocklist to block trackers and advertisements",
            description = "This is a curated and well-maintained blocklist to block ads, tracking, and more! Updated regularly.",
            creditName = "anudeepND",
            creditUrl = "https://github.com/anudeepND/blacklist",
            configs = listOf("Adservers", "Facebook")
        )
            .changeStatus(config = "Adservers")
            .withSource(PackSource.new(urls = listOf("https://blokada.org/mirror/v5/blacklist/adservers/hosts.txt", "https://raw.githubusercontent.com/anudeepND/blacklist/master/adservers.txt"), applyFor = "Adservers"))
            .withSource(PackSource.new(urls = listOf("https://blokada.org/mirror/v5/blacklist/facebook/hosts.txt", "https://raw.githubusercontent.com/anudeepND/blacklist/master/facebook.txt"), applyFor = "Facebook")),

        Pack.mocked(id = "exodusprivacy", tags = listOf(Pack.recommended, Pack.official, "tracking", "privacy"),
            title = "Exodus Privacy",
            slugline = "Analyzes privacy concerns in Android applications",
            description = "This blocklist is based on The Exodus Privacy project, which analyses Android applications and looks for embedded trackers. A tracker is a piece of software meant to collect data about you, or what you do. This is a very small list, so you should also activate one of the more popular lists (like Energized).",
            creditName = "Exodus Privacy",
            creditUrl = "https://go.blokada.org/exodusprivacy",
            configs = listOf("Standard")
        )
            .changeStatus(config = "Standard")
            .withSource(PackSource.new(urls = listOf("https://blokada.org/mirror/v5/exodusprivacy/standard/hosts.txt", "https://blokada.org/blocklists/exodusprivacy/standard/hosts.txt"), applyFor = "Standard")),

        Pack.mocked(id = "developerdan", tags = listOf(Pack.official, "adblocking", "tracking", "privacy", "social"),
            title = "Developer Dan's Hosts",
            slugline = "A blocklist for ads and tracking, updated regularly",
            description = "This is a good choice as the primary blocklist. It's well balanced, medium size, and frequently updated.",
            creditName = "Daniel White",
            creditUrl = "https://go.blokada.org/developerdan",
            configs = listOf("Ads & Tracking", "Facebook", "AMP", "Hate & Junk")
        )
            .changeStatus(config = "Ads & Tracking")
            .withSource(PackSource.new(urls = listOf("https://blokada.org/mirror/v5/developerdan/ads/hosts.txt", "https://www.github.developerdan.com/hosts/lists/ads-and-tracking-extended.txt"), applyFor = "Ads & Tracking"))
            .withSource(PackSource.new(urls = listOf("https://blokada.org/mirror/v5/developerdan/facebook/hosts.txt", "https://www.github.developerdan.com/hosts/lists/facebook-extended.txt"), applyFor = "Facebook"))
            .withSource(PackSource.new(urls = listOf("https://blokada.org/mirror/v5/developerdan/amp/hosts.txt", "https://www.github.developerdan.com/hosts/lists/amp-hosts-extended.txt"), applyFor = "AMP"))
            .withSource(PackSource.new(urls = listOf("https://blokada.org/mirror/v5/developerdan/junk/hosts.txt", "https://www.github.developerdan.com/hosts/lists/hate-and-junk-extended.txt"), applyFor = "Hate & Junk")),

        Pack.mocked(id = "blocklist", tags = listOf(Pack.official, "adblocking", "tracking", "privacy", "social", "security"),
            title = "The Block List Project",
            slugline = "A collection of blocklists for various use cases.",
            description = "These lists were created because the founder of the project wanted something with a little more control over what is being blocked.",
            creditName = "blocklistproject",
            creditUrl = "https://go.blokada.org/blocklistproject",
            configs = listOf("Ads", "Facebook", "Malware", "Phishing", "Tracking")
        )
            .changeStatus(config = "Ads")
            .withSource(PackSource.new(urls = listOf("https://blokada.org/mirror/v5/blocklist/ads/hosts.txt", "https://blocklistproject.github.io/Lists/ads.txt"), applyFor = "Ads"))
            .withSource(PackSource.new(urls = listOf("https://blokada.org/mirror/v5/blocklist/facebook/hosts.txt", "https://blocklistproject.github.io/Lists/facebook.txt"), applyFor = "Facebook"))
            .withSource(PackSource.new(urls = listOf("https://blokada.org/mirror/v5/blocklist/malware/hosts.txt", "https://blocklistproject.github.io/Lists/malware.txt"), applyFor = "Malware"))
            .withSource(PackSource.new(urls = listOf("https://blokada.org/mirror/v5/blocklist/phishing/hosts.txt", "https://blocklistproject.github.io/Lists/phishing.txt"), applyFor = "Phishing"))
            .withSource(PackSource.new(urls = listOf("https://blokada.org/mirror/v5/blocklist/tracking/hosts.txt", "https://blocklistproject.github.io/Lists/tracking.txt"), applyFor = "Tracking")),

        Pack.mocked(id = "spam404", tags = listOf(Pack.recommended, Pack.official, "privacy", "phishing", "security"),
            title = "Spam404",
            slugline = "A blocklist based on spam reports",
            description = "Spam404 is a service that helps online companies with content monitoring, penetration testing and brand protection. This list is based on the reports received from companies.",
            creditName = "spam404",
            creditUrl = "https://go.blokada.org/spam404",
            configs = listOf("Standard")
        )
            .changeStatus(config = "Standard")
            .withSource(PackSource.new(urls = listOf("https://blokada.org/mirror/v5/spam404/standard/hosts.txt", "https://raw.githubusercontent.com/Spam404/lists/master/main-blacklist.txt"), applyFor = "Standard")),

        Pack.mocked(id = "hblock", tags = listOf(Pack.official, "adblocking", "tracking", "phishing", "security"),
            title = "hBlock",
            slugline = "A comprehensive lists to block ads and tracking",
            description = "hBlock is a list with domains that serve ads, tracking scripts and malware. It prevents your device from connecting to them.",
            creditName = "hblock",
            creditUrl = "https://go.blokada.org/hblock",
            configs = listOf("Standard")
        )
            .changeStatus(config = "Standard")
            .withSource(PackSource.new(urls = listOf("https://blokada.org/mirror/v5/hblock/standard/hosts.txt", "https://hblock.molinero.dev/hosts_domains.txt"), applyFor = "Standard")),

        Pack.mocked(id = "cpbl", tags = listOf(Pack.official, "adblocking", "tracking", "privacy", "security"),
            title = "Combined Privacy Block Lists",
            slugline = "A general purpose, medium weight list",
            description = "This list blocks malicious and harmfully deceptive content, like advertising, tracking, telemetry, scam, and malware servers. This list does not block porn, social media, or so-called fake news domains. CPBL aims to provide block lists that offer comprehensive protection, while remaining reasonable in size and scope.",
            creditName = "bongochong",
            creditUrl = "https://go.blokada.org/cpbl",
            configs = listOf("Standard", "Mini")
        )
            .changeStatus(config = "Standard")
            .withSource(PackSource.new(urls = listOf("https://blokada.org/mirror/v5/cpbl/standard/hosts.txt", "https://raw.githubusercontent.com/bongochong/CombinedPrivacyBlockLists/master/newhosts-final.hosts"), applyFor = "Standard"))
            .withSource(PackSource.new(urls = listOf("https://blokada.org/mirror/v5/cpbl/mini/hosts.txt", "https://raw.githubusercontent.com/bongochong/CombinedPrivacyBlockLists/master/MiniLists/mini-newhosts.hosts"), applyFor = "Mini")),

        Pack.mocked(id = "danpollock", tags = listOf(Pack.official, "adblocking", "tracking"),
            title = "Dan Pollock's Hosts",
            slugline = "A reasonably balanced ad blocking hosts file",
            description = "This is a well known, general purpose blocklist of small size, updated regularly.",
            creditName = "Dan Pollock",
            creditUrl = "https://go.blokada.org/danpollock",
            configs = listOf("Standard")
        )
            .changeStatus(config = "Standard")
            .withSource(PackSource.new(urls = listOf("https://blokada.org/mirror/v5/danpollock/standard/hosts.txt", "https://someonewhocares.org/hosts/hosts"), applyFor = "Standard")),

        Pack.mocked(id = "urlhaus", tags = listOf(Pack.recommended, Pack.official, "security"),
            title = "URLhaus",
            slugline = "A blocklist based on malware database",
            description = "A blocklist of malicious websites that are being used for malware distribution, based on urlhaus.abuse.ch.",
            creditName = "curben",
            creditUrl = "https://go.blokada.org/urlhaus",
            configs = listOf("Standard")
        )
            .changeStatus(config = "Standard")
            .withSource(PackSource.new(urls = listOf("https://blokada.org/mirror/v5/urlhaus/standard/hosts.txt", "https://curben.gitlab.io/malware-filter/urlhaus-filter-hosts.txt"), applyFor = "Standard")),

        Pack.mocked(id = "1hosts", tags = listOf(Pack.official, "adblocking", "tracking"),
            title = "1Hosts",
            slugline = "A blocklist for ads and tracking, updated regularly",
            description = "Protect your data & eyeballs from being auctioned to the highest bidder. Please choose Light configuration first. If it is not good enough for you, try Pro instead.",
            creditName = "badmojr",
            creditUrl = "https://go.blokada.org/1hosts",
            configs = listOf("Lite (Wildcards)", "Pro (Wildcards)", "Xtra (Wildcards)")
        )
            .changeStatus(config = "Lite (Wildcards)")
            .withSource(PackSource.new(urls = listOf("https://blokada.org/mirror/v5/1hosts/lite (wildcards)/hosts.txt", "https://hosts.netlify.app/Lite/adblock.txt"), applyFor = "Lite (Wildcards)"))
            .withSource(PackSource.new(urls = listOf("https://blokada.org/mirror/v5/1hosts/pro (wildcards)/hosts.txt", "https://hosts.netlify.app/Pro/adblock.txt"), applyFor = "Pro (Wildcards)"))
            .withSource(PackSource.new(urls = listOf("https://blokada.org/mirror/v5/1hosts/xtra (wildcards)/hosts.txt", "https://hosts.netlify.app/Xtra/adblock.txt"), applyFor = "Xtra (Wildcards)")),

        Pack.mocked(id = "d3host", tags = listOf(Pack.official, "adblocking", "tracking"),
            title = "d3Host",
            slugline = "A blocklist from the maker of the adblocker test",
            description = "This is the official blocklist from d3ward, the maker of the popular adblocker testing website. It is meant to achieve 100% score in the test. Keep in mind, this is a minimum list. You may want to use it together with another blocklist activated. If you wish to perform the test, just visit go.blokada.org/test",
            creditName = "d3ward",
            creditUrl = "https://go.blokada.org/d3host",
            configs = listOf("Standard")
        )
            .changeStatus(config = "Standard")
            .withSource(PackSource.new(urls = listOf("https://blokada.org/mirror/v5/d3host/standard/hosts.txt", "https://raw.githubusercontent.com/d3ward/toolz/master/src/d3host.txt"), applyFor = "Standard")),
    )
}
