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

import org.blokada.R
import service.ContextService
import ui.utils.cause

open class BlokadaException(
    private val msg: String, private val reason: Throwable? = null
): Exception(msg, reason) {
    override fun toString(): String {
        return if (reason != null) {
            msg.cause(reason)
        } else super.toString()
    }
}

class TooManyDevices(cause: Throwable? = null): BlokadaException("Too many devices", cause)
class SystemTunnelRevoked: BlokadaException("Revoked")
class NoPersistedAccount: BlokadaException("No persisted account")
class NoPermissions: BlokadaException("No VPN profile permissions")
class TunnelFailure(cause: Throwable): BlokadaException("Tunnel failure: ${cause.message}", cause)
class BlockaDnsInFilteringMode(): BlokadaException("Blocka DNS in filtering mode")
class NoPayments(): BlokadaException("Payments are unavailable")
class TimeoutException(owner: String, cause: Throwable? = null): BlokadaException("Task timeout: $owner", cause)
class NoRelevantPurchase: BlokadaException("Found no relevant purchase")

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

suspend fun <T> runIgnoringException(block: suspend (() -> T), otherwise: T): T {
    return try {
        block()
    } catch (ex: Throwable) { otherwise }
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