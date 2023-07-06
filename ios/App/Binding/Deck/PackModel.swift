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

typealias PackId = String
typealias PackSourceId = String

/// Localised are strings that are suppposed to be localised (translated)
typealias Localised = String

/// Tags help the user choose among interesting packs and may indicate
/// various things about the pack. They are used in the UI for filtering.
/// Examples: ads, trackers, porn, ipv6, regional, Poland, China
typealias Tag = String

/// SourceType tells the app how to use the source data.
/// Examples: hostlist, iplist, easylist, safariplugin
typealias SourceType = String

typealias Url = String

/// A Pack may define zero to many PackConfigs which define its
/// behavior. For example, some hostlists exist in several variants,
/// from small to big size.
typealias PackConfig = String

struct Pack: Codable, Identifiable {
    let id: PackId
    let tags: [Tag]
    let sources: [PackSource]
    let meta: PackMetadata
    let configs: [PackConfig]
    let status: PackStatus
}

struct PackMetadata: Codable {
    let title: Localised
    let slugline: Localised
    let description: Localised
    let creditName: String
    let creditUrl: Url
    let rating: Int?
}

struct PackSource: Codable {
    let id: PackSourceId
    let urls: [Url]
    let liveUpdateUrl: Url?
    let applyFor: [PackConfig]?
    let whitelist: Bool
}

struct PackStatus: Codable {
    let installed: Bool
    let updatable: Bool
    var installing: Bool = false
    let badge: Bool
    let config: [PackConfig]
    let hits: Int

    private enum CodingKeys: String, CodingKey {
        // Dont persist "installing"
        case installed, updatable, badge, config, hits
    }

    init(installed: Bool, updatable: Bool, installing: Bool,
         badge: Bool, config: [PackConfig], hits: Int) {
        self.installed = installed
        self.updatable = updatable
        self.installing = installing
        self.badge = badge
        self.config = config
        self.hits = hits
    }
}

struct Packs: Codable {
    let packs: [Pack]
    let version: Int?
}

extension Pack: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension Pack: Equatable {
    static func == (lhs: Pack, rhs: Pack) -> Bool {
        lhs.id == rhs.id
    }
}

extension Pack {
    static func mocked(id: PackId, tags: [Tag] = [],
                       title: String, slugline: String = "", description: String = "",
                       creditName: String = "", creditUrl: String = "",
                       configs: [PackConfig] = []) -> Pack {
        return Pack(id: id, tags: tags, sources: [], meta: PackMetadata(
            title: title, slugline: slugline, description: description,
            creditName: creditName, creditUrl: creditUrl, rating: nil),
            configs: configs,
            status: PackStatus(installed: false, updatable: false, installing: false, badge: false, config: [], hits: 0))
    }
}

extension PackSource {
    static func new(url: Url, applyFor: PackConfig) -> PackSource {
        return PackSource(id: "xxx", urls: [url], liveUpdateUrl: nil, applyFor: [applyFor], whitelist: false)
    }
}

extension Pack {
    static let recommended = "recommended"
    static let official = "official"

    func allTagsCommaSeparated() -> String {
        if tags.isEmpty {
            return L10n.packTagsNone
        } else {
            return tags.map { $0.trTag() }.joined(separator: ", ").capitalizingFirstLetter()
        }
    }

    func changeStatus(installed: Bool? = nil, updatable: Bool? = nil, installing: Bool? = nil, badge: Bool? = nil,
                      enabledConfig: [PackConfig]? = nil, config: PackConfig? = nil, hits: Int? = nil) -> Pack {
        return Pack(id: self.id, tags: self.tags, sources: self.sources, meta: self.meta, configs: self.configs, status: PackStatus(
                installed: installed ?? self.status.installed,
                updatable: updatable ?? self.status.updatable,
                installing: installing ?? self.status.installing,
                badge: badge ?? self.status.badge,
                config: enabledConfig ?? switchConfig(config: config),
                hits: hits ?? self.status.hits
        ))
    }

    private func switchConfig(config: PackConfig?) -> [PackConfig] {
        var newConfig = (config == nil ? self.status.config :
        self.status.config.contains(config!) ? self.status.config.filter { $0 != config! }: self.status.config + [config!])

        if newConfig.isEmpty {
            // Dont allow to have empty config (unless originally it's empty)
            newConfig = self.status.config
        }

        return newConfig
    }

    func withSource(_ source: PackSource) -> Pack {
        return Pack(id: self.id, tags: self.tags, sources: self.sources + [source], meta: self.meta, configs: self.configs, status: self.status)
    }

    func getUrls() -> [Url] {
        if configs.isEmpty {
            // For packs without configs, just take all sources
            return sources.flatMap { $0.urls }.unique()
        } else {
            let activeSources = self.sources.filter {
                if $0.applyFor == nil {
                    return false
                } else {
                    return !Set($0.applyFor!).intersection(self.status.config).isEmpty
                }
            }

            if activeSources.isEmpty {
                BlockaLogger.w("Pack", "No matching sources for chosen configuration, choosing first")
                return self.sources.first!.urls
            } else {
                return activeSources.flatMap { $0.urls }.unique()
            }
        }
    }
}
