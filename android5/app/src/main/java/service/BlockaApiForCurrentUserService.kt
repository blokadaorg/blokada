/*
 * This file is part of Blokada.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Copyright © 2022 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package service

import kotlinx.coroutines.flow.first
import model.*
import repository.Repos
import utils.Logger

object BlockaApiForCurrentUserService {

    private val env = EnvironmentService

    val client by lazy { BlockaApiService }

    private val accountIdHot by lazy { Repos.account.accountIdHot }

    suspend fun getDeviceForCurrentUser(): DevicePayload {
        return client.getDevice(accountIdHot.first())
    }

    suspend fun putActivityRetentionForCurrentUser(retention: CloudActivityRetention) {
        val id = accountIdHot.first()
        val request = DeviceRequest(
            account_id = id,
            lists = null,
            retention = retention,
            paused = null
        )
        client.putDevice(request)
    }

    suspend fun putPausedForCurrentUser(paused: Boolean) {
        val id = accountIdHot.first()
        val request = DeviceRequest(
            account_id = id,
            lists = null,
            retention = null,
            paused = paused
        )
        client.putDevice(request)
    }

    suspend fun putBlocklistsForCurrentUser(lists: CloudBlocklists) {
        val id = accountIdHot.first()
        val request = DeviceRequest(
            account_id = id,
            lists = lists.toTypedArray(),
            retention = null,
            paused = null
        )
        client.putDevice(request)
    }

    suspend fun getActivityForCurrentUserAndDevice(): List<Activity> {
        val id = accountIdHot.first()
        val activity = client.getActivity(id)
        // return activity.filter { it.device_name == env.getDeviceAlias() }
        return activity
    }

    suspend fun getCustomListForCurrentUser(): List<CustomListEntry> {
        val id = accountIdHot.first()
        return client.getCustomList(id)
    }

    suspend fun postCustomListForCurrentUser(entry: CustomListEntry) {
        val id = accountIdHot.first()
        val request = CustomListRequest(
            account_id = id,
            domain_name = entry.domain_name,
            action = entry.action
        )
        client.postCustomList(request)
    }

    suspend fun deleteCustomListForCurrentUser(domainName: String) {
        val id = accountIdHot.first()
        val request = CustomListRequest(
            account_id = id,
            domain_name = domainName,
            action = "fallthrough"
        )
        client.deleteCustomList(request)
    }

    suspend fun getStatsForCurrentUser(): CounterStats {
        val id = accountIdHot.first()
        return client.getStats(id)
    }

    suspend fun getBlocklistsForCurrentUser(): List<Blocklist> {
        val id = accountIdHot.first()
        return client.getBlocklists(id)
    }

    suspend fun getLeasesForCurrentUser(): List<Lease> {
        val id = accountIdHot.first()
        return client.getLeases(id)
    }

    suspend fun deleteLeasesForCurrentUserAndDevice() {
        val leases = getLeasesForCurrentUser()
        leases.firstOrNull { it.alias == env.getDeviceAlias() }?.let {
            val request = LeaseRequest(
                account_id = it.account_id,
                public_key = it.public_key,
                gateway_id = it.gateway_id,
                alias = it.alias!!
            )
            Logger.w("BlockaApi", "Deleting one active lease for current alias")
            client.deleteLease(request)
        }
    }

    suspend fun postGplayCheckoutForCurrentUser(payload: PaymentPayload): Account {
        val id = accountIdHot.first()
        val request = GoogleCheckoutRequest(
            account_id = id,
            purchase_token = payload.purchase_token,
            subscription_id = payload.subscription_id
        )
        return client.postGplayCheckout(request)
    }

}