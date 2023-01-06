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