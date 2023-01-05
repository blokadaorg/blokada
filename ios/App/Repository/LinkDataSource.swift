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

class LinkDataSource {

    let links = [
        Link.ManageSubscriptions: "https://apps.apple.com/account/subscriptions",
        Link.WhyVpn: "https://go.blokada.org/vpn",
        Link.WhatIsDns: "https://go.blokada.org/dns",
        Link.WhyVpnPermissions: "https://go.blokada.org/vpnperms",
        Link.CloudDnsSetup: "https://go.blokada.org/cloudsetup_ios",
        Link.HowToRestore: "https://go.blokada.org/vpnrestore",
        Link.Support: "https://app.blokada.org/support?account-id=$ACCOUNTID&user-agent=$USERAGENT",
        Link.KnowledgeBase: "https://go.blokada.org/kb_ios",
        Link.Privacy: "https://go.blokada.org/privacy",
        Link.CloudPrivacy: "https://go.blokada.org/privacy_cloud",
        Link.Tos: "https://go.blokada.org/terms",
        Link.Credits: "https://blokada.org/"
    ]

}
