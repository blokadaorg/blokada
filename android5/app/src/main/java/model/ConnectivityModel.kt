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

import android.content.Context
import com.squareup.moshi.JsonClass
import org.blokada.R
import repository.DnsDataSource

@JsonClass(generateAdapter = true)
data class NetworkDescriptor(
    val name: String?,
    val type: NetworkType = NetworkType.FALLBACK
) {

    companion object {
        fun wifi(name: String?) = NetworkDescriptor(name, NetworkType.WIFI)
        fun cell(name: String?) = NetworkDescriptor(name, NetworkType.CELLULAR)
        fun fallback() = NetworkDescriptor(null, NetworkType.FALLBACK)
    }

    fun id() = "$type:$name"
    fun isFallback() = type == NetworkType.FALLBACK

    override fun toString(): String {
        return "($name, type=$type)"
    }

}

enum class NetworkType {
    WIFI, CELLULAR, FALLBACK
}

@JsonClass(generateAdapter = true)
data class NetworkSpecificConfig(
    val network: NetworkDescriptor,
    val enabled: Boolean,
    val encryptDns: Boolean,
    val useNetworkDns: Boolean,
    val dnsChoice: DnsId,
    val useBlockaDnsInPlusMode: Boolean,
    val forceLibreMode: Boolean
) {

    override fun toString(): String {
        return summarize().joinToString(", ") {
            if (it.second is Boolean) it.first
            else "${it.first}:${it.second}"
        }
    }

    fun summarizeLocalised(ctx: Context): String {
        return summarize().mapNotNull {
            when (it.first) {
                "encryptDns" -> ctx.getString(R.string.networks_action_encrypt_dns)
                "useNetworkDns" -> ctx.getString(R.string.networks_action_use_network_dns)
                "dnsChoice" -> ctx.getString(
                    R.string.networks_action_use_dns,
                    DnsDataSource.byId(it.second as DnsId).label
                )
                "forceLibreMode" -> ctx.getString(R.string.networks_action_force_libre_mode)
                else -> null
            }
        }.joinToString(", ")
    }

    fun summarize(): List<Pair<String, Any>> {
        return listOf(
            "encryptDns" to encryptDns,
            "useNetworkDns" to useNetworkDns,
            "dnsChoice" to dnsChoice,
            "useBlockaDnsInPlusMode" to useBlockaDnsInPlusMode,
            "forceLibreMode" to forceLibreMode,
        ).filter { it.second !is Boolean || it.second == true }
    }
}

typealias NetworkId = String

@JsonClass(generateAdapter = true)
data class NetworkSpecificConfigs(
    val configs: List<NetworkSpecificConfig>
)
