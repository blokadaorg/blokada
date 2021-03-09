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

package repository

import model.*

object PackDataSource {

    // Copypasted and adapted from iOS
    fun getPacks() = listOf(
        Pack.mocked(id = "oisd", tags = listOf(Pack.recommended, Pack.official, "adblocking", "tracking", "privacy", "phishing", "security"),
            title = "OISD",
            slugline = "A good, small, general purpose blocklist",
            description = "This universal list primarily blocks ads, and mobile app ads. Should not interfere with normal apps and services.",
            creditName = "sjhgvr",
            creditUrl = "https://oisd.nl/",
            configs = listOf("Basic (Wildcards)", "Basic")
        )
            .changeStatus(config = "Basic (Wildcards)")
            .changeStatus(installed = true) // Default config. Will auto download.
            .withSource(PackSource.new(url = "https://blokada.org/mirror/v5/oisd/basicw/hosts.txt", applyFor = "Basic (Wildcards)"))
            .withSource(PackSource.new(url = "https://blokada.org/mirror/v5/oisd/light/hosts.txt", applyFor = "Basic")),

    Pack.mocked(id = "energized", tags = listOf(Pack.official, "adblocking", "tracking", "privacy", "adult", "social", "regional"),
            title = "Energized",
            slugline = "Ads and trackers blocking list",
            description = "This Energized System is designed for Unix-like systems, gets a list of domains that serve ads, tracking scripts and malware from multiple reputable sources and creates a hosts file that prevents your system from connecting to them. Beware, installing \"Social\" configuration may make your social apps, like Messenger, misbehave.",
            creditName = "Team Boltz",
            creditUrl = "https://energized.pro/",
            configs = listOf("Spark", "Blu", "Basic", "Adult", "Regional", "Social", "Ultimate")
        )
            .changeStatus(config = "Blu")
            .withSource(PackSource.new(url = "https://blokada.org/mirror/v5/energized/spark/hosts.txt", applyFor = "Spark"))
            .withSource(PackSource.new(url = "https://blokada.org/mirror/v5/energized/blu/hosts.txt", applyFor = "Blu"))
            .withSource(PackSource.new(url = "https://blokada.org/mirror/v5/energized/basic/hosts.txt", applyFor = "Basic"))
            .withSource(PackSource.new(url = "https://blokada.org/mirror/v5/energized/adult/hosts.txt", applyFor = "Adult"))
            .withSource(PackSource.new(url = "https://blokada.org/mirror/v5/energized/regional/hosts.txt", applyFor = "Regional"))
            .withSource(PackSource.new(url = "https://blokada.org/mirror/v5/energized/social/hosts.txt", applyFor = "Social"))
            .withSource(PackSource.new(url = "https://blokada.org/mirror/v5/energized/ultimate/hosts.txt", applyFor = "Ultimate")),

        Pack.mocked(id = "stevenblack", tags = listOf(Pack.official, "adblocking", "tracking", "privacy", "adult", "social", "fake news", "gambling"),
            title = "Steven Black",
            slugline = "Popular for adblocking",
            description = "Consolidating and Extending hosts files from several well-curated sources. You can optionally pick extensions to block Porn, Social Media, and other categories.",
            creditName = "Steven Black",
            creditUrl = "https://github.com/StevenBlack/hosts",
            configs = listOf("Unified", "Fake news", "Adult", "Social", "Gambling")
        )
            .changeStatus(config = "Unified")
            .withSource(PackSource.new(url = "https://blokada.org/mirror/v5/stevenblack/unified/hosts.txt", applyFor = "Unified"))
            .withSource(PackSource.new(url = "https://blokada.org/mirror/v5/stevenblack/fakenews/hosts.txt", applyFor = "Fake news"))
            .withSource(PackSource.new(url = "https://blokada.org/mirror/v5/stevenblack/adult/hosts.txt", applyFor = "Adult"))
            .withSource(PackSource.new(url = "https://blokada.org/mirror/v5/stevenblack/social/hosts.txt", applyFor = "Social"))
            .withSource(PackSource.new(url = "https://blokada.org/mirror/v5/stevenblack/gambling/hosts.txt", applyFor = "Gambling")),

        Pack.mocked(id = "goodbyeads", tags = listOf(Pack.recommended, Pack.official, "adblocking", "tracking", "privacy", "youtube"),
            title = "Goodbye Ads",
            slugline = "Alternative blocklist with advanced features",
            description = "A blocklist with unique extensions to choose from. Be aware it is more aggressive, and may break apps or sites. It blocks graph.facebook.com and mqtt-mini.facebook.com. You may consider whitelisting them in the Activity section, in case you experience problems with Facebook apps.",
            creditName = "Jerryn70",
            creditUrl = "https://github.com/jerryn70/GoodbyeAds",
            configs = listOf("Standard", "YouTube", "Samsung", "Xiaomi", "Spotify")
        )
            .changeStatus(config = "Standard")
            .withSource(PackSource.new(url = "https://blokada.org/mirror/v5/goodbyeads/standard/hosts.txt", applyFor = "Standard"))
            .withSource(PackSource.new(url = "https://blokada.org/mirror/v5/goodbyeads/youtube/hosts.txt", applyFor = "YouTube"))
            .withSource(PackSource.new(url = "https://blokada.org/mirror/v5/goodbyeads/samsung/hosts.txt", applyFor = "Samsung"))
            .withSource(PackSource.new(url = "https://blokada.org/mirror/v5/goodbyeads/xiaomi/hosts.txt", applyFor = "Xiaomi"))
            .withSource(PackSource.new(url = "https://blokada.org/mirror/v5/goodbyeads/spotify/hosts.txt", applyFor = "Spotify")),

        Pack.mocked(id = "adaway", tags = listOf(Pack.official, "adblocking"),
            title = "AdAway",
            slugline = "Adblocking for your mobile device",
            description = "A special blocklist containing mobile ad providers.",
            creditName = "AdAway Team",
            creditUrl = "https://github.com/AdAway/AdAway",
            configs = listOf("Standard")
        )
            .changeStatus(config = "Standard")
            .withSource(PackSource.new(url = "https://blokada.org/mirror/v5/adaway/standard/hosts.txt", applyFor = "Standard")),

        Pack.mocked(id = "phishingarmy", tags = listOf(Pack.recommended, Pack.official, "phishing", "security"),
            title = "Phishing Army",
            slugline = "Protects against cyber attacks",
            description = "A blocklist to filter phishing websites. Phishing is a malpractice based on redirecting to fake websites, which look exactly like the original ones, in order to trick visitors, and steal sensitive information. Installing this blocklist will help you prevent such situations.",
            creditName = "Andrea Draghetti",
            creditUrl = "https://phishing.army/index.html",
            configs = listOf("Standard", "Extended")
        )
            .changeStatus(config = "Standard")
            .withSource(PackSource.new(url = "https://blokada.org/mirror/v5/phishingarmy/standard/hosts.txt", applyFor = "Standard"))
            .withSource(PackSource.new(url = "https://blokada.org/mirror/v5/phishingarmy/extended/hosts.txt", applyFor = "Extended")),

        Pack.mocked(id = "ddgtrackerradar", tags = listOf(Pack.recommended, Pack.official, "tracking", "privacy"),
            title = "DuckDuckGo Tracker Radar",
            slugline = "A new and expanding tracker database",
            description = "DuckDuckGo Tracker Radar is a best-in-class data set about trackers that is automatically generated and maintained through continuous crawling and analysis. See the author information for details.",
            creditName = "DuckDuckGo",
            creditUrl = "https://go.blokada.org/ddgtrackerradar",
            configs = listOf("Standard")
        )
            .changeStatus(config = "Standard")
            .withSource(PackSource.new(url = "https://blokada.org/mirror/v5/ddgtrackerradar/standard/hosts.txt", applyFor = "Standard")),

        Pack.mocked(id = "blacklist", tags = listOf(Pack.official, "adblocking", "tracking", "privacy"),
            title = "Blacklist",
            slugline = "Curated blocklist to block trackers and advertisements",
            description = "This is a curated and well-maintained blocklist to block ads, tracking, and more! Updated regularly.",
            creditName = "anudeepND",
            creditUrl = "https://github.com/anudeepND/blacklist",
            configs = listOf("Adservers", "Facebook")
        )
            .changeStatus(config = "Adservers")
            .withSource(PackSource.new(url = "https://blokada.org/mirror/v5/blacklist/adservers/hosts.txt", applyFor = "Adservers"))
            .withSource(PackSource.new(url = "https://blokada.org/mirror/v5/blacklist/facebook/hosts.txt", applyFor = "Facebook")),

        Pack.mocked(id = "exodusprivacy", tags = listOf(Pack.recommended, Pack.official, "tracking", "privacy"),
            title = "Exodus Privacy",
            slugline = "Analyzes privacy concerns in Android applications",
            description = "This blocklist is based on The Exodus Privacy project, which analyses Android applications and looks for embedded trackers. A tracker is a piece of software meant to collect data about you, or what you do. This is a very small list, so you should also enable one of the more popular lists (like Energized).",
            creditName = "Exodus Privacy",
            creditUrl = "https://go.blokada.org/exodusprivacy",
            configs = listOf("Standard")
        )
            .changeStatus(config = "Standard")
            .withSource(PackSource.new(url = "https://blokada.org/mirror/v5/exodusprivacy/standard/hosts.txt", applyFor = "Standard")),

        Pack.mocked(id = "developerdan", tags = listOf(Pack.recommended, Pack.official, "adblocking", "tracking", "privacy", "social"),
            title = "Developer Dan's Hosts",
            slugline = "A blocklist for ads and tracking, updated regularly",
            description = "This is a good choice as the primary blocklist. It's well balanced, medium size, and frequently updated.",
            creditName = "Daniel White",
            creditUrl = "https://go.blokada.org/developerdan",
            configs = listOf("Ads & Tracking", "Facebook", "AMP", "Hate & Junk")
        )
            .changeStatus(config = "Ads & Tracking")
            .withSource(PackSource.new(url = "https://blokada.org/mirror/v5/developerdan/ads/hosts.txt", applyFor = "Ads & Tracking"))
            .withSource(PackSource.new(url = "https://blokada.org/mirror/v5/developerdan/facebook/hosts.txt", applyFor = "Facebook"))
            .withSource(PackSource.new(url = "https://blokada.org/mirror/v5/developerdan/amp/hosts.txt", applyFor = "AMP"))
            .withSource(PackSource.new(url = "https://blokada.org/mirror/v5/developerdan/junk/hosts.txt", applyFor = "Hate & Junk")),

        Pack.mocked(id = "blocklist", tags = listOf(Pack.recommended, Pack.official, "adblocking", "tracking", "privacy", "social", "youtube"),
            title = "The Block List Project",
            slugline = "A collection of blocklists for various use cases.",
            description = "These lists were created because the founder of the project wanted something with a little more control over what is being blocked.",
            creditName = "blocklistproject",
            creditUrl = "https://go.blokada.org/blocklistproject",
            configs = listOf("Ads", "Facebook", "Malware", "Phishing", "Tracking", "YouTube")
        )
            .changeStatus(config = "Ads")
            .withSource(PackSource.new(url = "https://blokada.org/mirror/v5/blocklist/ads/hosts.txt", applyFor = "Ads"))
            .withSource(PackSource.new(url = "https://blokada.org/mirror/v5/blocklist/facebook/hosts.txt", applyFor = "Facebook"))
            .withSource(PackSource.new(url = "https://blokada.org/mirror/v5/blocklist/malware/hosts.txt", applyFor = "Malware"))
            .withSource(PackSource.new(url = "https://blokada.org/mirror/v5/blocklist/phishing/hosts.txt", applyFor = "Phishing"))
            .withSource(PackSource.new(url = "https://blokada.org/mirror/v5/blocklist/tracking/hosts.txt", applyFor = "Tracking"))
            .withSource(PackSource.new(url = "https://blokada.org/mirror/v5/blocklist/youtube/hosts.txt", applyFor = "YouTube")),

        Pack.mocked(id = "spam404", tags = listOf(Pack.recommended, Pack.official, "privacy", "phishing", "security"),
            title = "Spam404",
            slugline = "A blocklist based on spam reports",
            description = "Spam404 is a service that helps online companies with content monitoring, penetration testing and brand protection. This list is based on the reports received from companies.",
            creditName = "spam404",
            creditUrl = "https://go.blokada.org/spam404",
            configs = listOf("Standard")
        )
            .changeStatus(config = "Standard")
            .withSource(PackSource.new(url = "https://blokada.org/mirror/v5/spam404/standard/hosts.txt", applyFor = "Standard")),

        Pack.mocked(id = "hblock", tags = listOf(Pack.recommended, Pack.official, "adblocking", "tracking", "phishing", "security"),
            title = "hBlock",
            slugline = "A comprehensive lists to block ads and tracking",
            description = "hBlock is a list with domains that serve ads, tracking scripts and malware. It prevents your device from connecting to them.",
            creditName = "hblock",
            creditUrl = "https://go.blokada.org/hblock",
            configs = listOf("Standard")
        )
            .changeStatus(config = "Standard")
            .withSource(PackSource.new(url = "https://blokada.org/mirror/v5/hblock/standard/hosts.txt", applyFor = "Standard"))
    )
}
