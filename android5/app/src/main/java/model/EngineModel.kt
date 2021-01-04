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

package model

import repository.DnsDataSource

class TunnelStatus private constructor (
    val active: Boolean,
    val inProgress: Boolean = false,
    val restarting: Boolean = false,
    val error: BlokadaException? = null,
    val isUsingDnsOverHttps: Boolean = false,
    val dns: Dns? = null,
    val gatewayId: GatewayId? = null,
    val gatewayLabel: String = "",
    val desiredGatewayId: GatewayId? = null // When user wants Plus mode, but we can't run VPN because of chosen network config
) {

    fun isDnsEncrypted() = when {
        !active -> false
        dns == DnsDataSource.network -> false
        else -> isUsingDnsOverHttps || isPlusMode()
    }

    fun isPlusMode() = active && gatewayId != null
    fun wantsPlusMode() = desiredGatewayId != null

    companion object {
        fun off() = TunnelStatus(
            active = false
        )

        fun inProgress() = TunnelStatus(
            active = false,
            inProgress = true
        )

        fun filteringOnly(dns: Dns, doh: Boolean, desiredGatewayId: GatewayId?) = TunnelStatus(
            active = true,
            inProgress = false,
            isUsingDnsOverHttps = doh,
            dns = dns,
            desiredGatewayId = desiredGatewayId
        )

        fun connected(dns: Dns, doh: Boolean, gateway: Gateway) = TunnelStatus(
            active = true,
            isUsingDnsOverHttps = doh,
            dns = dns,
            gatewayId = gateway.public_key,
            desiredGatewayId = gateway.public_key,
            gatewayLabel = gateway.niceName()
        )

        fun noPermissions() = TunnelStatus(
            active = false,
            error = NoPermissions()
        )

        fun error(ex: BlokadaException) = TunnelStatus(
            active = false,
            error = ex
        )

        fun restarting() = TunnelStatus(
            active = false,
            inProgress = true,
            restarting = true
        )
    }
}