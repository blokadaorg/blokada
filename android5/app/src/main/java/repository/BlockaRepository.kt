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

package repository

import model.Account
import model.AccountId
import model.Lease
import model.LeaseRequest

object BlockaRepository {

    private val dataSource = BlockaDataSource

    suspend fun createAccount() = dataSource.postAccount()
    suspend fun fetchAccount(accountId: AccountId) = dataSource.getAccount(accountId)
    suspend fun fetchGateways() = dataSource.getGateways()
    suspend fun fetchLeases(accountId: AccountId) = dataSource.getLeases(accountId)
    suspend fun createLease(leaseRequest: LeaseRequest) = dataSource.postLease(leaseRequest)

    suspend fun deleteLease(accountId: AccountId, lease: Lease) = dataSource.deleteLease(
        LeaseRequest(
            account_id = accountId,
            public_key = lease.public_key,
            gateway_id = lease.gateway_id,
            alias = lease.alias ?: ""
        )
    )

}