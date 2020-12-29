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

typealias DnsIp = String
typealias DnsId = String

@JsonClass(generateAdapter = true)
data class Dns(
    val id: DnsId,
    val ips: List<DnsIp>,
    val plusIps: List<DnsIp>? = null,
    val port: Int?,
    val name: String?,
    val path: String?,
    val label : String,
    val canUseInCleartext: Boolean = true,
    val region: String = "worldwide"
) {
    companion object {
        fun plaintextDns(
            id: DnsId,
            ips: List<DnsIp>,
            label : String,
            region: String = "worldwide"
        ) = Dns(id, ips, null, null, null, null, label, region = region)
    }

    override fun toString(): String {
        return "Dns(id='$id', ips=$ips, plusIps=$plusIps, canUseInCleartext=$canUseInCleartext)"
    }

}

@JsonClass(generateAdapter = true)
data class DnsWrapper(
    val value: List<Dns>
)

fun Dns.isDnsOverHttps() = name != null
fun DnsIp.isIpv4() = contains(".")

fun DnsIp.isIpv6() = contains(":")

fun List<DnsIp>.ipv4() = filter { it.isIpv4() }
fun List<DnsIp>.ipv6() = filter { it.isIpv6() }
