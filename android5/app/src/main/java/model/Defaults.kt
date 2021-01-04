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
import repository.PackDataSource
import service.EnvironmentService

object Defaults {

    val PACKS_VERSION = 11

    fun stats() = StatsPersisted(entries = emptyMap())
    fun allowed() = Allowed(value = listOf())
    fun denied() = Denied(value = listOf())
    fun packs() = Packs(PackDataSource.getPacks(), version = PACKS_VERSION)
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
        dnsChoice = DnsDataSource.blocka.id,
        useBlockaDnsInPlusMode = true,
        enabled = false
    )

}
