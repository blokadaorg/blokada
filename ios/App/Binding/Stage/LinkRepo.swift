//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2022 Blocka AB. All rights reserved.
//
//  @author Karol Gusak
//

import Foundation
import Combine
import Factory

class LinkRepo {
    
    @Injected(\.link) private var links

    private lazy var systemNav = Services.systemNav

    private var cancellables = Set<AnyCancellable>()

    // Opens one of well known links, replacing any placeholders (like account id).
    func openLink(_ linkId: LinkId) {
        guard let link = self.links.links.value[linkId] else {
            return BlockaLogger.e("LinkRepo", "Unknown link: \(linkId)")
        }

        do {
            self.systemNav.openInBrowser(try linkToUrlComponents(link))
        } catch {
            BlockaLogger.e("LinkRepo", "Failed opening link: \(link)")
        }
    }

    // Opens custom link, does not replace any placeholders.
    func openLink(_ link: String) {
        Just(link)
        .tryMap { it in URL(string: it)! }
        .tryMap { it in URLComponents(url: it, resolvingAgainstBaseURL: false)! }
        .sink(
            onValue: { it in self.systemNav.openInBrowser(it) },
            onFailure: { err in BlockaLogger.e("LinkRepo", "Could not parse link: \(link)") }
        )
        .store(in: &cancellables)
    }

    private func linkToUrlComponents(
        _ link: String
    ) throws -> URLComponents {
        if !link.starts(with: "https://") {
            throw "LinkRepo: only https:// links are allowed"
        }

        var parts = link.dropFirst(8).split(separator: "/", maxSplits: 1)

        let host = String(parts[0])
        var path = "/"
        var queries: [URLQueryItem]? = nil

        if parts.count > 1 {
            parts = parts[1].split(separator: "?", maxSplits: 1)
            path = "/\(parts[0])"

            if parts.count > 1 {
                parts = parts[1].split(separator: "&", maxSplits: 1)
                queries = parts.map { it in
                    let keyValue = it.split(separator: "=", maxSplits: 1)
                    let value = String(keyValue[1])

                    return URLQueryItem(
                        name: String(keyValue[0]),
                        value: value
                    )
                }
            }
        }

        return getLinkFor(host: host, path: path, queries: queries)
    }

    private func getLinkFor(
        host: String, path: String, queries: [URLQueryItem]? = nil
    ) -> URLComponents {
        var url = URLComponents()
        url.scheme = "https"
        url.host = host
        url.path = path
        if let items = queries {
            url.queryItems = items
        }
        return url
    }
}
