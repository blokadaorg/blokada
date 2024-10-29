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

import binding.LegacyGateway
import binding.LegacyLease
import kotlinx.serialization.Serializable

@Serializable
data class BlockaConfig(
    val privateKey: PrivateKey,
    val publicKey: PublicKey,
    val keysGeneratedForAccountId: AccountId,
    val keysGeneratedForDevice: DeviceId,
    val lease: LegacyLease?,
    val gateway: LegacyGateway?,
    val vpnEnabled: Boolean,
    val tunnelEnabled: Boolean = false
) {
    fun lease() = lease!!
    fun gateway() = gateway!!
}

// These settings are never backed up to the cloud
@Serializable
data class LocalConfig(
    val dnsChoice: DnsId, // Deprecated
    val useChromeTabs: Boolean = false,
    val useDarkTheme: Boolean? = null,
    val themeName: String? = null,
    val locale: String? = null,
    val ipv6: Boolean = true, // Deprecated
    val backup: Boolean = true,
    val useDnsOverHttps: Boolean = false, // Deprecated
    val useBlockaDnsInPlusMode: Boolean = true, // Deprecated
    val escaped: Boolean = false,
    val useForegroundService: Boolean = false, // Deprecated
    val pingToCheckNetwork: Boolean = false
)

// These settings are always backed up to the cloud (if possible)
@Serializable
data class SyncableConfig(
    val rateAppShown: Boolean,
    val notFirstRun: Boolean,
    val rated: Boolean = false
)
