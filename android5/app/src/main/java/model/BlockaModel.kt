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

import com.squareup.moshi.JsonClass
import java.util.*

typealias AccountId = String
typealias GatewayId = String
typealias PrivateKey = String
typealias PublicKey = String
typealias ActiveUntil = Date
typealias DeviceId = String

@JsonClass(generateAdapter = true)
data class AccountWrapper(val account: Account)

@JsonClass(generateAdapter = true)
data class LeaseWrapper(val lease: Lease)

@JsonClass(generateAdapter = true)
data class Gateways(val gateways: List<Gateway>)

@JsonClass(generateAdapter = true)
data class Leases(val leases: List<Lease>)

@JsonClass(generateAdapter = true)
data class Account(
    val id: AccountId,
    val active_until: ActiveUntil = Date(0),
    val active: Boolean?,
    val type: String?,
    val payment_source: String?
) {
    fun isActive() = active ?: false
    fun getType() = type.toAccountType()
    fun getSource() = payment_source

    override fun toString(): String {
        return "Account(activeUntil=$active_until, type=$type)"
    }
}

@JsonClass(generateAdapter = true)
data class Gateway(
    val public_key: PublicKey,
    val region: String,
    val location: String,
    val resource_usage_percent: Int,
    val ipv4: String,
    val ipv6: String,
    val port: Int,
    val tags: List<String>?,
    val country: String?
) {
    fun niceName() = location.split('-').map { it.capitalize() }.joinToString(" ")
    fun overloaded() = resource_usage_percent >= 100

    companion object {}
}

@JsonClass(generateAdapter = true)
data class Lease(
    val account_id: AccountId,
    val public_key: PublicKey,
    val gateway_id: GatewayId,
    val expires: ActiveUntil,
    val alias: String?,
    val vip4: String,
    val vip6: String
) {
    fun niceName() = if (alias?.isNotBlank() == true) alias else public_key.take(5)

    fun isActive() = expires > Date()

    override fun toString(): String {
        // No account ID
        return "Lease(publicKey='$public_key', gatewayId='$gateway_id', expires=$expires, alias=$alias, vip4='$vip4', vip6='$vip6')"
    }

    companion object {}
}

@JsonClass(generateAdapter = true)
data class LeaseRequest(
    val account_id: AccountId,
    val public_key: PublicKey,
    val gateway_id: GatewayId,
    val alias: String
) {
    override fun toString(): String {
        // No account ID
        return "LeaseRequest(publicKey='$public_key', gatewayId='$gateway_id', alias='$alias')"
    }
}

@JsonClass(generateAdapter = true)
data class ActivityWrapper(
    val activity: List<Activity>
)

@JsonClass(generateAdapter = true)
data class Activity(
    val device_name: String,
    val domain_name: String,
    val action: String,
    val list: String,
    val timestamp: String
)

@JsonClass(generateAdapter = true)
data class DeviceWrapper(
    val device: DevicePayload
)

@JsonClass(generateAdapter = true)
data class DevicePayload(
    val device_tag : String,
    val lists: List<String>,
    val retention: String,
    val paused: Boolean
)

@JsonClass(generateAdapter = true)
data class DeviceRequest(
    val account_id: AccountId,
    val lists: Array<String>?,
    val retention: String?,
    val paused: Boolean?
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false

        other as DeviceRequest

        if (account_id != other.account_id) return false
        if (lists != null) {
            if (other.lists == null) return false
            if (!lists.contentEquals(other.lists)) return false
        } else if (other.lists != null) return false
        if (retention != other.retention) return false
        if (paused != other.paused) return false

        return true
    }

    override fun hashCode(): Int {
        var result = account_id.hashCode()
        result = 31 * result + (lists?.contentHashCode() ?: 0)
        result = 31 * result + (retention?.hashCode() ?: 0)
        result = 31 * result + (paused?.hashCode() ?: 0)
        return result
    }
}

@JsonClass(generateAdapter = true)
data class Blocklist(
    val id: String,
    val name: String,
    val managed: Boolean,
    val is_allowlist: Boolean
)

// Our internal version of the Blocklist
data class MappedBlocklist(
    val id: String,
    val packId: String,
    val packConfig: String
)

@JsonClass(generateAdapter = true)
data class BlocklistWrapper(
    val lists: List<Blocklist>
)

@JsonClass(generateAdapter = true)
data class ExceptionWrapper(
    val customlist: List<CustomListEntry>
)

@JsonClass(generateAdapter = true)
data class CustomListEntry(
    val domain_name: String,
    val action: String
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false

        other as CustomListEntry

        if (domain_name != other.domain_name) return false
        if (action != other.action) return false

        return true
    }

    override fun hashCode(): Int {
        var result = domain_name.hashCode()
        result = 31 * result + action.hashCode()
        return result
    }
}

@JsonClass(generateAdapter = true)
data class CustomListRequest(
    val account_id: AccountId,
    val domain_name: String,
    val action: String
)

@JsonClass(generateAdapter = true)
data class CustomListWrapper(
    val customlist: List<CustomListEntry>
)

@JsonClass(generateAdapter = true)
data class CounterStats(
    val total_allowed: String,
    val total_blocked: String
) {
    fun getCounter(): Long {
        return total_blocked.toLong()
    }
}

@JsonClass(generateAdapter = true)
data class GoogleCheckoutRequest(
    val account_id: AccountId,
    val purchase_token: String,
    val subscription_id: String
)

data class PaymentPayload(
    val purchase_token: String,
    val subscription_id: String,
    val user_initiated: Boolean
)

fun Gateway.Companion.mocked(name: String) = Gateway(
    public_key = "mocked-$name",
    region = "mocked",
    location = name,
    resource_usage_percent = 0,
    ipv4 = "0.0.0.0",
    ipv6 = ":",
    port = 8080,
    tags = listOf(),
    country = "SE"
)

fun Lease.Companion.mocked(name: String) = Lease(
    public_key = "mocked-$name",
    account_id = "mockedmocked",
    gateway_id = name,
    expires = Date(),
    alias = name,
    vip6 = ":",
    vip4 = "0.0.0.0"
)