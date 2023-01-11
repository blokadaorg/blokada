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

package utils

import service.EnvironmentService
import java.net.URLEncoder

object Links {

    val intro = "https://go.blokada.org/introadblocking"
    val whyUpgrade = "https://go.blokada.org/vpn"
    val whatIsDns = "https://go.blokada.org/dns"
    val whyVpnPerms = "https://go.blokada.org/vpnperms"
    val howToRestore = "https://go.blokada.org/vpnrestore"
    val tunnelFailure = "https://go.blokada.org/tunnelfailure"
    val connIssues = "https://go.blokada.org/connissues"
    val startOnBoot = "https://go.blokada.org/startonboot"

    val kb = "https://go.blokada.org/kb_android"
    val donate = "https://go.blokada.org/donate"
    val privacy = "https://go.blokada.org/privacy"
    val terms = "https://go.blokada.org/terms"
    val credits = "https://blokada.org/"
    val community = "https://go.blokada.org/forum"
    val changelog = "https://go.blokada.org/changelog"

    val updated = "https://go.blokada.org/updated_android"

    fun manageSubscriptions(accountId: String) = "https://app.blokada.org/activate/$accountId"

    fun support(accountId: String) =
        "https://app.blokada.org/support?account-id=$accountId" +
        "&user-agent=${URLEncoder.encode(EnvironmentService.getUserAgent())}"

    fun isSubscriptionLink(link: String) = link.startsWith("https://app.blokada.org/activate")

    fun isAvoidWebView(link: String) = isSubscriptionLink(link) || link == donate
}
