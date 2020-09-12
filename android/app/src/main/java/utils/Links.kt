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
    val startOnBoot = "https://go.blokada.org/startonboot"

    val kb = "https://go.blokada.org/kb_android"
    val donate = "https://go.blokada.org/donate"
    val privacy = "https://go.blokada.org/privacy"
    val terms = "https://go.blokada.org/terms"
    val credits = "https://go.blokada.org/credits"
    val community = "https://go.blokada.org/forum"

    val updated =
        if (EnvironmentService.isSlim()) "https://go.blokada.org/updated_android_slim"
        else "https://go.blokada.org/updated_android"

    fun manageSubscriptions(accountId: String) =
        if (EnvironmentService.isSlim()) support(accountId)
        else "https://app.blokada.org/activate/$accountId"

    fun support(accountId: String) =
        "https://app.blokada.org/support?account-id=$accountId" +
        "&user-agent=${URLEncoder.encode(EnvironmentService.getUserAgent())}"

    fun isSubscriptionLink(link: String) = link.startsWith("https://app.blokada.org/activate")

}
