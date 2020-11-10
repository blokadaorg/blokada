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

import org.blokada.R
import service.ContextService
import service.tr

open class BlokadaException(msg: String, cause: Throwable? = null): Exception(msg, cause)

class TooManyDevices(cause: Throwable? = null): BlokadaException("Too many devices", cause)
class SystemTunnelRevoked: BlokadaException("Revoked")
class NoPersistedAccount: BlokadaException("No persisted account")
class NoPermissions: BlokadaException("No VPN profile permissions")
class TunnelFailure(cause: Throwable): BlokadaException("Tunnel failure: ${cause.message}", cause)
class BlockaDnsInFilteringMode(): BlokadaException("Blocka DNS in filtering mode")

fun mapErrorToUserFriendly(ex: Exception?): String {
    val ctx = ContextService.requireAppContext()
    var string = when {
        ex?.cause is BlockaDnsInFilteringMode -> ctx.getString(R.string.error_blocka_dns_in_filtering_mode)
        ex is TooManyDevices -> ctx.getString(R.string.error_vpn_too_many_leases)
        ex is TunnelFailure -> ctx.getString(R.string.error_tunnel)
        ex is NoPermissions -> ctx.getString(R.string.error_vpn_perms)
        else -> ctx.getString(R.string.error_unknown)

    }
    string += "\n\n(debug info: ${ex?.message?.atMost(100) ?: "none"})"
    return string
}

fun shouldShowKbLink(ex: Exception?): Boolean {
    return when {
        ex is TunnelFailure -> true
        else -> false
    }
}

fun String.ex(): BlokadaException {
    return BlokadaException(this)
}

private fun String.atMost(size: Int): String {
    return if (length <= size) this else this.substring(0..size)
}