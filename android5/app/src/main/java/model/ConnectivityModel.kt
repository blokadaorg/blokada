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

import android.content.Context
import com.squareup.moshi.JsonClass
import org.blokada.R
import repository.DnsDataSource
import service.ConnectivityService

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
        ).filter { it.second !is Boolean || it.second == true }
    }
}

typealias NetworkId = String

@JsonClass(generateAdapter = true)
data class NetworkSpecificConfigs(
    val configs: List<NetworkSpecificConfig>
)
