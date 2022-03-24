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

import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.asFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import model.CloudActivityRetention
import model.CloudBlocklists
import model.DevicePayload
import model.DeviceRequest
import repository.AccountRepo
import repository.Repos
import ui.AccountViewModel
import ui.MainApplication

object BlockaApiForCurrentUserService {

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

//    func getActivityForCurrentUserAndDevice() -> AnyPublisher<[Activity], Error> {
//        return accountRepo.accountIdHot.first()
//            .flatMap { it in self.client.getActivity(id: it) }
//            //.tryMap { it in it.filter { $0.device_name == self.envRepo.deviceName }}
//            .eraseToAnyPublisher()
//    }
//
//    func getCustomListForCurrentUser() -> AnyPublisher<[CustomListEntry], Error> {
//        return accountRepo.accountIdHot.first()
//            .flatMap { it in self.client.getCustomList(id: it) }
//            .eraseToAnyPublisher()
//    }
//
//    func postCustomListForCurrentUser(_ entry: CustomListEntry) -> AnyPublisher<Ignored, Error> {
//        return accountRepo.accountIdHot.first()
//            .map { it in CustomListRequest(
//                account_id: it,
//                domain_name: entry.domain_name,
//                action: entry.action
//                )}
//            .flatMap { it in self.client.postCustomList(request: it) }
//            .eraseToAnyPublisher()
//    }
//
//    func deleteCustomListForCurrentUser(_ domainName: String) -> AnyPublisher<Ignored, Error> {
//        return accountRepo.accountIdHot.first()
//            .map { it in CustomListRequest(
//                account_id: it,
//                domain_name: domainName,
//                action: "fallthrough"
//                )}
//            .flatMap { it in self.client.deleteCustomList(request: it) }
//            .eraseToAnyPublisher()
//    }
//
//    func getStatsForCurrentUser() -> AnyPublisher<CounterStats, Error> {
//        return accountRepo.accountIdHot.first()
//            .flatMap { it in self.client.getStats(id: it) }
//            .eraseToAnyPublisher()
//    }
//
//    func getBlocklistsForCurrentUser() -> AnyPublisher<[Blocklist], Error> {
//        return accountRepo.accountIdHot.first()
//            .flatMap { it in self.client.getBlocklists(id: it) }
//            .eraseToAnyPublisher()
//    }
//
//    func getLeasesForCurrentUser() -> AnyPublisher<[Lease], Error> {
//        return accountRepo.accountIdHot.first()
//            .flatMap { it in self.client.getLeases(id: it) }
//            .eraseToAnyPublisher()
//    }
//
//    func deleteLeasesForCurrentUserAndDevice() -> AnyPublisher<Ignored, Error> {
//        return getLeasesForCurrentUser()
//            .tryMap { leases -> LeaseRequest in
//                    if let it = leases.first(where: { $0.alias == self.envRepo.aliasForLease }) {
//                return LeaseRequest(
//                    account_id: it.account_id,
//                public_key: it.public_key,
//                gateway_id: it.gateway_id,
//                alias: it.alias
//                )
//            } else {
//                throw "Found no lease for current alias"
//            }
//            }
//            .flatMap { request -> AnyPublisher<Ignored, Error> in
//                    Logger.w("BlockaApi", "Deleting one active lease for current alias")
//                return self.client.deleteLease(request: request)
//            }
//            .eraseToAnyPublisher()
//    }
}