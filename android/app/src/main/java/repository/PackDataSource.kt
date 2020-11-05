/*
 * This file is part of Blokada.
 *
 * Blokada is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Blokada is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Blokada.  If not, see <https://www.gnu.org/licenses/>.
 *
 * Copyright © 2020 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package repository

import model.*

object PackDataSource {

    // Copypasted and adapted from iOS
    fun getPacks() = listOf(
        Pack.mocked(id = "energized", tags = listOf(Pack.recommended, Pack.official, "adblocking", "tracking", "privacy", "adult", "social", "regional"),
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
            .withSource(PackSource.new(url = "https://blokada.org/mirror/v5/phishingarmy/extended/hosts.txt", applyFor = "Standard"))
            .withSource(PackSource.new(url = "https://blokada.org/mirror/v5/phishingarmy/extended/hosts.txt", applyFor = "Extended")),

        Pack.mocked(id = "ddgtrackerradar", tags = listOf(Pack.recommended, Pack.official, "tracking", "privacy"),
            title = "DuckDuckGo Tracker Radar",
            slugline = "A new and upcoming tracker database",
            description = "DuckDuckGo Tracker Radar is a best-in-class data set about trackers that is automatically generated and maintained through continuous crawling and analysis. See the author information for details.",
            creditName = "DuckDuckGo",
            creditUrl = "https://go.blokada.org/ddgtrackerradar",
            configs = listOf("Standard")
        )
            .changeStatus(config = "Standard")
            .withSource(PackSource.new(url = "https://blokada.org/blocklists/ddgtrackerradar/standard/hosts.txt", applyFor = "Standard")),

        Pack.mocked(id = "blacklist", tags = listOf(Pack.recommended, Pack.official, "adblocking", "tracking", "privacy"),
            title = "Blacklist",
            slugline = "Curated blocklist to block trackers and advertisements",
            description = "This is a curated and well-maintained blocklist to block ads, tracking, and more! Updated regularly.",
            creditName = "anudeepND",
            creditUrl = "https://github.com/anudeepND/blacklist",
            configs = listOf("Adservers", "Facebook")
        )
            .changeStatus(config = "Adservers")
            .withSource(PackSource.new(url = "https://blokada.org/mirror/v5/blacklist/adservers/hosts.txt", applyFor = "Adservers"))
            .withSource(PackSource.new(url = "https://blokada.org/mirror/v5/blacklist/facebook/hosts.txt", applyFor = "Facebook"))
    )
}