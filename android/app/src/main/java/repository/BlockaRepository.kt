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