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

import com.squareup.moshi.JsonClass
import service.EnvironmentService

@JsonClass(generateAdapter = true)
data class BlockaConfig(
    val privateKey: PrivateKey,
    val publicKey: PublicKey,
    val keysGeneratedForAccountId: AccountId,
    val keysGeneratedForDevice: DeviceId,
    val lease: Lease?,
    val gateway: Gateway?,
    val vpnEnabled: Boolean,
    val tunnelEnabled: Boolean = false
) {
    fun getAccountId() = keysGeneratedForAccountId
}

// These settings are never backed up to the cloud
@JsonClass(generateAdapter = true)
data class LocalConfig(
    val dnsChoice: DnsId,
    val useChromeTabs: Boolean = false,
    val useDarkTheme: Boolean? = null,
    val themeName: String? = null,
    val locale: String? = null,
    val ipv6: Boolean = true,
    val backup: Boolean = true,
    val useDnsOverHttps: Boolean = false,
    val useBlockaDnsInPlusMode: Boolean = true,
    val escaped: Boolean = false
)

// These settings are always backed up to the cloud (if possible)
@JsonClass(generateAdapter = true)
data class SyncableConfig(
    val rateAppShown: Boolean,
    val notFirstRun: Boolean,
    val rated: Boolean = false
)
