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
import repository.PackDataSource
import service.EnvironmentService

object Defaults {

    val PACKS_VERSION = 17

    fun stats() = StatsPersisted(entries = emptyMap())
    fun allowed() = Allowed(value = listOf())
    fun denied() = Denied(value = listOf())
    fun packs() = Packs(PackDataSource.getPacks(), version = PACKS_VERSION, lastRefreshMillis = 0)
    fun localConfig() = LocalConfig(dnsChoice = BuildSpecificDefaults.dns)
    fun syncableConfig() = SyncableConfig(rateAppShown = false, notFirstRun = false)
    fun dnsWrapper() = DnsWrapper(DnsDataSource.getDns())

    fun blockaConfig() = BlockaConfig(
        privateKey = "",
        publicKey = "",
        keysGeneratedForAccountId = "",
        keysGeneratedForDevice = EnvironmentService.getDeviceId(),
        lease = null,
        gateway = null,
        vpnEnabled = false
    )

    fun adsCounter() = AdsCounter(persistedValue = 0L)

    fun bypassedAppIds() = BypassedAppIds(emptyList()) // Also check AppRepository

    fun blockaRepoConfig() = BlockaRepoConfig(
        name = "default",
        forBuild = "*"
    )

    fun noSeenUpdate() = BlockaRepoUpdate(
        mirrors = emptyList(),
        infoUrl = "",
        newest = ""
    )

    fun noPayload() = BlockaRepoPayload(
        cmd = ""
    )

    fun noAfterUpdate() = BlockaAfterUpdate()

    fun noNetworkSpecificConfigs() = NetworkSpecificConfigs(configs = listOf(
        defaultNetworkConfig(),
        defaultNetworkConfig().copy(network = NetworkDescriptor.cell(null)),
        defaultNetworkConfig().copy(network = NetworkDescriptor.wifi(null))
    ))

    fun networkConfig(network: NetworkDescriptor) = defaultNetworkConfig().copy(network = network)

    fun defaultNetworkConfig() = NetworkSpecificConfig(
        network = NetworkDescriptor.fallback(),
        encryptDns = true,
        useNetworkDns = false,
        dnsChoice = DnsDataSource.cloudflare.id,
        useBlockaDnsInPlusMode = true,
        enabled = false
    )

}
