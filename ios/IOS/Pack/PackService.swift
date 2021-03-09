//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2020 Blocka AB. All rights reserved.
//
//  @author Karol Gusak
//

import Foundation

class PackService {

    static let shared = PackService()

    var onPacksUpdated = { (packs: [Pack]) in }

    private let log = Logger("Pack")
    private let packDownloader = PackDownloader()

    private var hardcodedPacks = [
        Pack.mocked(id: "oisd", tags: [Pack.recommended, Pack.official, "adblocking", "tracking", "privacy", "phishing", "security"],
            title: "OISD",
            slugline: "A good general purpose blocklist",
            description: "Blocks ads, phishing, malware, spyware, ransomware, scam, telemetry, analytics, tracking (where not needed for proper functionality). Should not interfere with normal apps and services.",
            creditName: "sjhgvr",
            creditUrl: "https://go.blokada.org/oisd",
            configs: ["Light"]
        )
            .changeStatus(config: "Light")
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/oisd/light/hosts.txt", applyFor: "Light")),

        Pack.mocked(id: "energized", tags: [Pack.official, "adblocking", "tracking", "privacy", "adult", "social", "regional"],
            title: "Energized",
            slugline: "Ads and trackers blocking list",
            description: "This Energized System is designed for Unix-like systems, gets a list of domains that serve ads, tracking scripts and malware from multiple reputable sources and creates a hosts file that prevents your system from connecting to them. Beware, installing \"Social\" configuration may make your social apps, like Messenger, misbehave.",
            creditName: "Team Boltz",
            creditUrl: "https://energized.pro/",
            configs: ["Spark", "Blu", "Basic", "Adult", "Regional", "Social", "Ultimate"]
        )
            .changeStatus(config: "Blu")
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/energized/spark/hosts.txt", applyFor: "Spark"))
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/energized/blu/hosts.txt", applyFor: "Blu"))
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/energized/basic/hosts.txt", applyFor: "Basic"))
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/energized/adult/hosts.txt", applyFor: "Adult"))
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/energized/regional/hosts.txt", applyFor: "Regional"))
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/energized/social/hosts.txt", applyFor: "Social"))
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/energized/ultimate/hosts.txt", applyFor: "Ultimate")),

        Pack.mocked(id: "stevenblack", tags: [Pack.official, "adblocking", "tracking", "privacy", "adult", "social", "fake news", "gambling"],
            title: "Steven Black",
            slugline: "Popular for adblocking",
            description: "Consolidating and Extending hosts files from several well-curated sources. You can optionally pick extensions to block Porn, Social Media, and other categories.",
            creditName: "Steven Black",
            creditUrl: "https://github.com/StevenBlack/hosts",
            configs: ["Unified", "Fake news", "Adult", "Social", "Gambling"]
        )
            .changeStatus(config: "Unified")
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
            configs: ["Standard", "YouTube", "Spotify"]
        )
            .changeStatus(config: "Standard")
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/goodbyeads/standard/hosts.txt", applyFor: "Standard"))
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/goodbyeads/youtube/hosts.txt", applyFor: "YouTube"))
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/goodbyeads/spotify/hosts.txt", applyFor: "Spotify")),

        Pack.mocked(id: "adaway", tags: [Pack.official, "adblocking"],
               title: "AdAway",
               slugline: "Adblocking for your mobile device",
               description: "A special blocklist containing mobile ad providers.",
               creditName: "AdAway Team",
               creditUrl: "https://github.com/AdAway/AdAway",
               configs: ["Standard"]
           )
               .changeStatus(config: "Standard")
               .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/adaway/standard/hosts.txt", applyFor: "Standard")),

        Pack.mocked(id: "phishingarmy", tags: [Pack.recommended, Pack.official, "phishing", "security"],
            title: "Phishing Army",
            slugline: "Protects against cyber attacks",
            description: "A blocklist to filter phishing websites. Phishing is a malpractice based on redirecting to fake websites, which look exactly like the original ones, in order to trick visitors, and steal sensitive information. Installing this blocklist will help you prevent such situations.",
            creditName: "Andrea Draghetti",
            creditUrl: "https://phishing.army/index.html",
            configs: ["Standard", "Extended"]
        )
            .changeStatus(config: "Standard")
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
            .changeStatus(config: "Standard")
            .withSource(PackSource.new(url: "https://blokada.org/blocklists/ddgtrackerradar/standard/hosts.txt", applyFor: "Standard")),

        Pack.mocked(id: "blacklist", tags: [Pack.official, "adblocking", "tracking", "privacy"],
            title: "Blacklist",
            slugline: "Curated blocklist to block trackers and advertisements",
            description: "This is a curated and well-maintained blocklist to block ads, tracking, and more! Updated regularly.",
            creditName: "anudeepND",
            creditUrl: "https://github.com/anudeepND/blacklist",
            configs: ["Adservers", "Facebook"]
        )
            .changeStatus(config: "Adservers")
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/blacklist/adservers/hosts.txt", applyFor: "Adservers"))
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/blacklist/facebook/hosts.txt", applyFor: "Facebook")),

        Pack.mocked(id: "developerdan", tags: [Pack.recommended, Pack.official, "adblocking", "tracking", "privacy", "social"],
            title: "Developer Dan's Hosts",
            slugline: "A blocklist for ads and tracking, updated regularly",
            description: "This is a good choice as the primary blocklist. It's well balanced, medium size, and frequently updated.",
            creditName: "Daniel White",
            creditUrl: "https://go.blokada.org/developerdan",
            configs: ["Ads & Tracking", "Facebook", "AMP", "Hate & Junk"]
        )
            .changeStatus(config: "Ads & Tracking")
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/developerdan/ads/hosts.txt", applyFor: "Ads & Tracking"))
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/developerdan/facebook/hosts.txt", applyFor: "Facebook"))
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/developerdan/amp/hosts.txt", applyFor: "AMP"))
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/developerdan/junk/hosts.txt", applyFor: "Hate & Junk")),

        Pack.mocked(id: "blocklist", tags: [Pack.recommended, Pack.official, "adblocking", "tracking", "privacy", "social", "youtube"],
            title: "The Block List Project",
            slugline: "A collection of blocklists for various use cases.",
            description: "These lists were created because the founder of the project wanted something with a little more control over what is being blocked.",
            creditName: "blocklistproject",
            creditUrl: "https://go.blokada.org/blocklistproject",
            configs: ["Ads", "Facebook", "Malware", "Phishing", "Tracking", "YouTube"]
        )
            .changeStatus(config: "Ads")
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/blocklist/ads/hosts.txt", applyFor: "Ads"))
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/blocklist/facebook/hosts.txt", applyFor: "Facebook"))
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/blocklist/malware/hosts.txt", applyFor: "Malware"))
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/blocklist/phishing/hosts.txt", applyFor: "Phishing"))
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/blocklist/tracking/hosts.txt", applyFor: "Tracking"))
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/blocklist/youtube/hosts.txt", applyFor: "YouTube")),

        Pack.mocked(id: "spam404", tags: [Pack.recommended, Pack.official, "privacy", "phishing", "security"],
            title: "Spam404",
            slugline: "A blocklist based on spam reports",
            description: "Spam404 is a service that helps online companies with content monitoring, penetration testing and brand protection. This list is based on the reports received from companies.",
            creditName: "spam404",
            creditUrl: "https://go.blokada.org/spam404",
            configs: ["Standard"]
        )
            .changeStatus(config: "Standard")
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/spam404/standard/hosts.txt", applyFor: "Standard")),

        Pack.mocked(id: "hblock", tags: [Pack.recommended, Pack.official, "adblocking", "tracking", "phishing", "security"],
            title: "hBlock",
            slugline: "A comprehensive lists to block ads and tracking",
            description: "hBlock is a list with domains that serve ads, tracking scripts and malware. It prevents your device from connecting to them.",
            creditName: "spam404",
            creditUrl: "https://go.blokada.org/hblock",
            configs: ["Standard"]
        )
            .changeStatus(config: "Standard")
            .withSource(PackSource.new(url: "https://blokada.org/mirror/v5/hblock/standard/hosts.txt", applyFor: "Standard")),
    ]

    private let packsVersion = 21

    private var packs = [Pack]()
    private var usingDefaultConfiguration = false

    private let persistence = UserDefaults.standard
    private let decoder = initJsonDecoder()
    private let encoder = initJsonEncoder()

    private func loadPacks() -> [Pack] {
        let result = persistence.string(forKey: "packs")
        guard let stringData = result else {
            return []
        }

        let jsonData = stringData.data(using: .utf8)
        guard let json = jsonData else {
            log.e("Failed getting packs json")
            return []
        }

        do {
            let packs = try self.decoder.decode(Packs.self, from: json)
            if packs.version ?? 0 < self.packsVersion {
                return migratePacks(old: packs.packs, new: hardcodedPacks)
            } else {
                return packs.packs
            }
        } catch {
            log.e("Failed decoding packs json".cause(error))
            return []
        }
    }

    private func persistPacks(_ packs: Packs) {
        guard let body = packs.toJson() else {
            return self.log.e("Failed encoding packs json")
        }

        persistence.set(body, forKey: "packs")
    }

    private init() {
        self.packs = loadPacks()
        if self.packs.isEmpty {
            self.resetToDefaults()
        }
    }

    func resetToDefaults() {
        self.log.w("Using hardcoded packs")
        self.packs = hardcodedPacks
        self.onPacksUpdated(self.packs)
        self.useHardcodedList()
        onBackground {
            self.persistPacks(Packs(packs: self.packs, version: self.packsVersion))
        }
    }

    private func migratePacks(old: [Pack], new: [Pack]) -> [Pack] {
        self.log.v("Migrating packs to version \(packsVersion)")
        return new.map { n in
            let oldPack = old.first { $0.id == n.id }
            guard let o = oldPack else {
                // A new item, just add it
                return n
            }

            return Pack(
                id: n.id,
                tags: n.tags,
                sources: n.sources,
                meta: n.meta,
                configs: n.configs,
                status: PackStatus(
                    installed: o.status.installed,
                    updatable: o.status.updatable,
                    installing: o.status.installing,
                    badge: o.status.badge,
                    config: o.status.config.filter { n.configs.contains($0) },
                    hits: o.status.hits
                )
            )
        }
    }

    func fetchPacks(ok: @escaping Ok<[Pack]>, fail: @escaping Fail) {
        onBackground {
            onMain {
                self.onPacksUpdated(self.packs)
                return ok(self.packs)
            }
        }
    }

    func installPack(pack: Pack, ok: @escaping Ok<Void>, fail: @escaping Fail) {
        self.update(pack.changeStatus(installing: true))
        onBackground {
            var urls = pack.getUrls()

            // Also include urls of any active pack
            let moreUrls = self.packs.filter { $0.status.installed }.flatMap { $0.getUrls() }
            urls = (urls + moreUrls).unique()

            self.downloadAll(urls: urls, ok: { _ in
                onBackground {
                    self.mergeSources(urls: urls, ok: { _ in
                        onMain {
                            self.update(pack.changeStatus(installed: true, updatable: false, installing: false))
                        }

                        onBackground {
                            NetworkService.shared.queryStatus { error, status in
                                if let status = status, status.active {
                                    self.log.v("Reloading blocklists in engine")
                                    NetworkService.shared.sendMessage(msg: "reload_lists") { _, _ in
                                        return ok(())
                                    }
                                } else {
                                    return ok(())
                                }
                            }
                        }
                    }, fail: { error in
                        onMain {
                            self.update(pack.changeStatus(installed: false, updatable: false, installing: false))
                            return fail(error)
                        }
                    })
                }
            }, fail: { error in
                onMain {
                    self.update(pack.changeStatus(installed: false, updatable: false, installing: false))
                    return fail(error)
                }
            })
        }
    }

    func uninstallPack(pack: Pack, ok: @escaping Ok<Void>, fail: @escaping Fail) {
        self.update(pack.changeStatus(installing: true))
        onBackground {
            // Uninstall any downloaded sources for this pack
            // We get all possible sources because user might have changed config and only then decided to uninstall
            let urlsToUninstall = pack.sources.flatMap { $0.urls }
            for url in urlsToUninstall {
                self.log.v("Removing downloaded source (if any): \(url)")
                self.packDownloader.remove(url: url)
            }

            // Include urls of any active pack
            let urls = self.packs.filter { $0.status.installed && $0.id != pack.id }.flatMap { $0.getUrls() }

            self.downloadAll(urls: urls, ok: { _ in
                onBackground {
                    self.mergeSources(urls: urls, ok: { _ in
                        onMain {
                            self.update(pack.changeStatus(installed: false, updatable: false, installing: false))
                        }

                        onBackground {
                            NetworkService.shared.queryStatus { error, status in
                                if let status = status, status.active {
                                    self.log.v("Reloading blocklists in engine")
                                    NetworkService.shared.sendMessage(msg: "reload_lists") { _, _ in
                                        return ok(())
                                    }
                                }
                            }
                        }
                    }, fail: { error in
                        onMain {
                            self.update(pack.changeStatus(installed: false, updatable: false, installing: false))
                        }
                    })
                }
            }, fail: { error in
                onMain {
                    self.update(pack.changeStatus(installed: false, updatable: false, installing: false))
                }
            })
        }
    }

    func reload() {
        onBackground {
            self.log.v("Reloading all blocklists")

            if self.usingDefaultConfiguration {
                self.useHardcodedList()
            } else {
                // Include urls of any active pack
                let urls = self.packs.filter { $0.status.installed }.flatMap { $0.getUrls() }.unique()

                // If they are downloaded already, they'll be fetched from cache files instead
                self.downloadAll(urls: urls, ok: { _ in
                    onBackground {
                        // Merging will also include user blocklist
                        self.mergeSources(urls: urls, ok: { _ in
                            onBackground {
                                NetworkService.shared.queryStatus { error, status in
                                    if let status = status, status.active {
                                        self.log.v("Reloading blocklists in engine")
                                        NetworkService.shared.sendMessage(msg: "reload_lists") { _, _ in }
                                    }
                                }
                            }
                        }, fail: { error in })
                    }
                }, fail: { error in })
            }
        }
    }

    func setBadge(pack: Pack) {
        self.update(pack.changeStatus(badge: true))
    }

    func unsetBadge(pack: Pack) {
        self.update(pack.changeStatus(badge: false))
    }

    func countBadges() -> Int? {
        let count = self.packs.map { $0.status.badge ? 1 : 0 }.reduce(0, +)
        return count == 0 ? nil : count
    }

    func changeConfig(pack: Pack, config: PackConfig, fail: @escaping Fail) {
        let updated = pack.changeStatus(installed: false, config: config)
        self.installPack(pack: updated, ok: { pack in
            
        }, fail: fail)
    }

    private func update(_ pack: Pack) {
        onMain {
            self.log.v("Pack: \(pack.id): installed: \(pack.status.installed)")
            self.packs = self.packs.map { $0.id == pack.id ? pack : $0 }
            self.onPacksUpdated(self.packs)
            self.checkConfiguration()

            onBackground {
                self.persistPacks(Packs(packs: self.packs, version: self.packsVersion))
            }
        }
    }

    private func downloadAll(urls: [Url], ok: @escaping Ok<Void>, fail: @escaping Fail) {
        onMain {
            var downloads = urls.count
            var errorNotified = false

            if urls.isEmpty {
                return ok(())
            }

            for url in urls {
                onBackground {
                    if self.packDownloader.hasDownloaded(url: url) {
                        self.log.v("Skipping download, already present: \(url)")
                        onMain {
                            downloads -= 1
                            if downloads == 0 {
                                return ok(())
                            }
                        }
                    } else {
                        self.packDownloader.download(url: url, ok: { _ in
                            onMain {
                                downloads -= 1
                                if downloads == 0 {
                                    return ok(())
                                }
                            }
                        }, fail: { error in
                            onMain {
                                if !errorNotified {
                                    errorNotified = true
                                    return fail(error)
                                }
                            }
                        })
                    }
                }
            }
        }
    }

    private func mergeSources(urls: [Url], ok: @escaping Ok<Void>, fail: @escaping Fail) {
        if urls.isEmpty {
            return ok(())
        }

        var files = urls.map {
            FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.net.blocka.app")!.appendingPathComponent("\($0)".toBase64())
        }
        
        if FileManager.default.fileExists(atPath: ActivityService.destinationBlacklist.path) {
            self.log.v("Including user blocklist")
            files.append(ActivityService.destinationBlacklist) // Always include user blocklist (whitelist is included using engine api)
        }

        let destination = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: "group.net.blocka.app")!.appendingPathComponent("hosts")

        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }

            self.log.v("Merging hosts files")
            try FileManager.default.merge(files: files, to: destination)
            ok(())
        } catch {
            return fail(error)
        }
    }

    private func checkConfiguration() {
        let anythingActivated = !self.packs.filter { $0.status.installed }.isEmpty
        if !anythingActivated && !self.usingDefaultConfiguration {
            self.log.v("Switching to hardcoded lists")
            self.usingDefaultConfiguration = true
            useHardcodedList()
        } else if anythingActivated {
            self.usingDefaultConfiguration = false
        }
    }

    private func useHardcodedList() {
        onBackground {
            self.log.v("Using default hardcoded list")

            var files = [Bundle(for: type(of : self)).url(forResource: "hosts", withExtension: "txt")!]

            if FileManager.default.fileExists(atPath: ActivityService.destinationBlacklist.path) {
                self.log.v("Including user blocklist")
                files.append(ActivityService.destinationBlacklist) // Always include user blocklist (whitelist is included using engine api)
            }

            let destination = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.net.blocka.app")!.appendingPathComponent("hosts")

            do {
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }

                self.log.v("Merging hardcoded blocklist with user blocklist")
                try FileManager.default.merge(files: files, to: destination)

                NetworkService.shared.queryStatus { error, status in
                    if let status = status, status.active {
                        self.log.v("Reloading blocklist")
                        NetworkService.shared.sendMessage(msg: "reload_lists") { _, _ in }
                    }
                }
            } catch {
                self.log.e("Failed using default list file".cause(error))
            }
        }
    }

    //    private var packs = [
    //        Pack.mocked(id: "45342345242", tags: ["recommended", "official", "adblocking", "privacy"],
    //            title: "Block ads and trackers",
    //            slugline: "BLOKADA recommended pack",
    //            description: "This is our recommended pack for blocking ads & trackers. It consists of several popular lists, namely Energized, Unified and more. You may choose how many rules to use.",
    //            creditName: "Various authors",
    //            creditUrl: "https://blokada.org",
    //            configs: ["Light version", "Full version"]
    //        ).changeStatus(installed: true, config: "Full version", hits: 99),
    //        Pack.mocked(id: "45241234252342", tags: ["recommended", "official", "privacy"],
    //            title: "Block Facebook",
    //            slugline: "Additional blocking of Facebook",
    //            description: "This pack blocks more Facebook connections, enabling better protection from tracking and fingerprinting. This may lead to breaking Facebook or other apps.",
    //            creditName: "BLOKADA",
    //            creditUrl: "https://blokada.org"
    //        ).changeStatus(),
    //        Pack.mocked(id: "324235234", tags: ["recommended"],
    //            title: "My blocked sites",
    //            slugline: "Websites manually blocked by you",
    //            description: "When manually block any site, it will land here.",
    //            creditName: "Various authors",
    //            creditUrl: "https://blokada.org"
    //        ).changeStatus(installed: true),
    //        Pack.mocked(id: "345324212524", tags: ["recommended"],
    //            title: "My allowed sites",
    //            slugline: "Websites manually allowed by you",
    //            description: "When manually allow any site, it will land here.",
    //            creditName: "Various authors",
    //            creditUrl: "https://blokada.org"
    //        ).changeStatus(installed: true),
    //        Pack.mocked(id: "25312424214", tags: ["official", "security", "privacy"],
    //            title: "Encrypt connections",
    //            slugline: "Secure connections with encryption",
    //            description: "When you enable this pack, BLOKADA will protect your connections by requiring encryption and rejecting the unencrypted ones.",
    //            creditName: "BLOKADA",
    //            creditUrl: "https://blokada.org",
    //            configs: ["Encrypt DNS (DNS over HTTPS)", "Require HTTPS", "Use VPN"]
    //        ).changeStatus(installed: true, config: "Encrypt DNS (DNS over HTTPS)"),
    //        Pack.mocked(id: "579879748298778", tags: ["recommended", "adult", "regional", "Japan"],
    //            title: "Block adult websites",
    //            slugline: "Protect your children from adult content",
    //            description: "This pack blocks all porn websites that exist.",
    //            creditName: "Family guy"
    //        ),
    //
    //        Pack.mocked(id: "35234234524252", tags: ["adblocking", "privacy"],
    //            title: "Energized",
    //            slugline: "A popular community pack",
    //            description: "A nice overall packs for blocking ads and annoyances. Please note that if you are using BLOKADA default blocklist, this one is already included.",
    //            creditName: "The Energized team",
    //            creditUrl: "https://blokada.org"
    //        ).changeStatus(installed: true, updatable: true, badge: true),
    //        Pack.mocked(id: "44534534534231232423423", tags: ["recommended", "privacy"],
    //            title: "EasyPrivacy",
    //            slugline: "A popular anti tracking pack",
    //            creditName: "The EasyPrivacy team",
    //            creditUrl: "https://blokada.org"
    //        ),
    //        Pack.mocked(id: "3",
    //            title: "Underscribed pack"
    //        ),
    //        Pack.mocked(id: "48797987987983", tags: ["adblocking", "privacy", "adult"],
    //            title: "Super long freaking awesome name pack",
    //            description: "This pack is great because it has lots of text. Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum.",
    //            creditName: "The Freaking Awesome Long Name Team"
    //        ),
    //
    //        Pack.mocked(id: "634535353453", tags: ["adblocking", "privacy"],
    //            title: "Super adblocking pack",
    //            description: "This pack will help you block everyday annoyances.",
    //            creditName: "The F-Society",
    //            configs: ["Light", "Full", "Extreme"]
    //        ).changeStatus(installed: true, updatable: true, badge: true, enabledConfig: ["Light"]),
    //        Pack.mocked(id: "7", tags: ["adblocking", "privacy", "regional", "China"],
    //            title: "China ads blocker",
    //            slugline: "Blocks out ads in China.",
    //            creditName: "The Chinese Ministry of Ads"
    //        ),
    //        Pack.mocked(id: "8", tags: ["adblocking", "privacy", "adult", "regional", "Poland"],
    //            title: "Universal pack for Poland",
    //            description: "A great choice for the Polish part of the Internet.",
    //            creditName: "Polish Party People"
    //        )
    //    ]

}
