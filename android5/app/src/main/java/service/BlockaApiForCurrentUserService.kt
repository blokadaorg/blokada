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

    private val api by lazy { BlockaApiService }

    private val accountIdHot by lazy { Repos.account.accountIdHot }

    suspend fun getDeviceForCurrentUser(): DevicePayload {
        return api.getDevice(accountIdHot.first())
    }

    suspend fun putActivityRetentionForCurrentUser(retention: CloudActivityRetention) {
        val id = accountIdHot.first()
        val request = DeviceRequest(
            account_id = id,
            lists = null,
            retention = retention,
            paused = null
        )
        api.putDevice(request)
    }

    suspend fun putPausedForCurrentUser(paused: Boolean) {
        val id = accountIdHot.first()
        val request = DeviceRequest(
            account_id = id,
            lists = null,
            retention = null,
            paused = paused
        )
        api.putDevice(request)
    }

    suspend fun putBlocklistsForCurrentUser(lists: CloudBlocklists) {
        val id = accountIdHot.first()
        val request = DeviceRequest(
            account_id = id,
            lists = lists.toTypedArray(),
            retention = null,
            paused = null
        )
        api.putDevice(request)
    }

    suspend fun getActivityForCurrentUserAndDevice(): List<Activity> {
        val id = accountIdHot.first()
        val activity = api.getActivity(id)
        // return activity.filter { it.device_name == env.getDeviceAlias() }
        return activity
    }

    suspend fun getCustomListForCurrentUser(): List<CustomListEntry> {
        val id = accountIdHot.first()
        return api.getCustomList(id)
    }

    suspend fun postCustomListForCurrentUser(entry: CustomListEntry) {
        val id = accountIdHot.first()
        val request = CustomListRequest(
            account_id = id,
            domain_name = entry.domain_name,
            action = entry.action
        )
        api.postCustomList(request)
    }

    suspend fun deleteCustomListForCurrentUser(domainName: String) {
        val id = accountIdHot.first()
        val request = CustomListRequest(
            account_id = id,
            domain_name = domainName,
            action = "fallthrough"
        )
        api.deleteCustomList(request)
    }

    suspend fun getStatsForCurrentUser(): CounterStats {
        val id = accountIdHot.first()
        return api.getStats(id)
    }

    suspend fun getBlocklistsForCurrentUser(): List<Blocklist> {
        val id = accountIdHot.first()
        return api.getBlocklists(id)
    }

    suspend fun getLeasesForCurrentUser(): List<Lease> {
        val id = accountIdHot.first()
        return api.getLeases(id)
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
            api.deleteLease(request)
        }
    }

}