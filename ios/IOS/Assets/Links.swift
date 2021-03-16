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
import SwiftUI

class Links {

    static func manageSubscriptions() -> URLComponents {
        return self.URLComponentsFor(
            host: "apps.apple.com",
            path: "/account/subscriptions",
            queries: nil
        )
    }

    static func whyVpn() -> URLComponents {
        return self.URLComponentsFor(
        host: "go.blokada.org", path: "/vpn", queries: nil)
    }

    static func whatIsDns() -> URLComponents {
        return self.URLComponentsFor(
        host: "go.blokada.org", path: "/dns", queries: nil)
    }


    static func whyVpnPermissions() -> URLComponents {
       return self.URLComponentsFor(
       host: "go.blokada.org", path: "/vpnperms", queries: nil)
   }

    static func howToRestore() -> URLComponents {
        return self.URLComponentsFor(
        host: "go.blokada.org", path: "/vpnrestore", queries: nil)
    }

    static func support() -> URLComponents {
        return self.URLComponentsFor(
            host: "app.blokada.org",
            path: "/support",
            queries: [
                URLQueryItem(name: "account-id", value: Config.shared.accountId()),
                URLQueryItem(name: "user-agent", value: BlockaApiService.userAgent())
            ])
    }

    static func knowledgeBase() -> URLComponents {
        return self.URLComponentsFor(
            host: "go.blokada.org", path: "/kb_ios", queries: nil)
    }

    static func privacy() -> URLComponents {
       return self.URLComponentsFor(
           host: "go.blokada.org", path: "/privacy", queries: nil)
    }

    static func tos() -> URLComponents {
       return self.URLComponentsFor(
           host: "go.blokada.org", path: "/terms", queries: nil)
    }

    static func credits() -> URLComponents {
        return self.URLComponentsFor(
            host: "blokada.org", path: "/", queries: nil)
    }

    static func openInBrowser(_ link: URLComponents) {
        if let url = link.url {
            UIApplication.shared.open(url, options: [:])
        }
    }

    private static func URLComponentsFor(host: String, path: String, queries: [URLQueryItem]?) -> URLComponents {
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
