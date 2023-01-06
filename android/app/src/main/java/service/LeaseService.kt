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

package service

import model.*
import ui.utils.cause
import utils.Logger

object LeaseService {

    private val log = Logger("Lease")
    private val blocka = BlockaApiService
    private val env = EnvironmentService

    suspend fun createLease(config: BlockaConfig, gateway: Gateway): Lease {
        log.w("Creating lease")
        val request = LeaseRequest(
            account_id = config.getAccountId(),
            public_key = config.publicKey,
            gateway_id = gateway.public_key,
            alias = env.getDeviceAlias()
        )

        try {
            return blocka.postLease(request)
        } catch (ex: TooManyDevices) {
            log.w("Too many devices, attempting to remove one lease")
            deleteLeaseWithAliasOfCurrentDevice(config)
            return blocka.postLease(request)
        }
    }

    suspend fun fetchLeases(accountId: AccountId): List<Lease> {
        return blocka.getLeases(accountId)
    }

    suspend fun deleteLease(lease: Lease) {
        log.w("Deleting lease")
        val request = LeaseRequest(
            account_id = lease.account_id,
            public_key = lease.public_key,
            gateway_id = lease.gateway_id,
            alias = lease.alias ?: ""
        )
        return blocka.deleteLease(request)
    }

    suspend fun checkLease(config: BlockaConfig) {
        if (config.vpnEnabled) config.lease?.let { lease ->
            log.v("Checking lease")
            config.gateway?.let { gateway ->
                try {
                    val currentLease = getCurrentLease(config, gateway)
                    if (!currentLease.isActive()) {
                        log.w("Lease expired, refreshing")
                        blocka.postLease(
                            LeaseRequest(
                                account_id = config.getAccountId(),
                                public_key = config.publicKey,
                                gateway_id = gateway.public_key,
                                alias = env.getDeviceAlias()
                            )
                        )
                    }
                } catch (ex: Exception) {
                    if (lease.isActive()) log.v("Cached is valid, ignoring")
                    else throw BlokadaException("No valid lease found".cause(ex))
                }
            } ?: throw BlokadaException("No gateway set in current BlockaConfig")
        }
    }

    private suspend fun getCurrentLease(config: BlockaConfig, gateway: Gateway): Lease {
        val leases = blocka.getLeases(config.getAccountId())
        if (leases.isEmpty()) throw BlokadaException("No leases found for this account")
        val current = leases.firstOrNull { it.public_key == config.publicKey && it.gateway_id == gateway.public_key }
        return current ?: throw BlokadaException("No lease found for this device")
    }

    // This is used to automatically clear the max devices limit, in some scenarios
    private suspend fun deleteLeaseWithAliasOfCurrentDevice(config: BlockaConfig) {
        log.v("Deleting lease with alias of current device")
        val leases = blocka.getLeases(config.getAccountId())
        val lease = leases.firstOrNull { it.alias == env.getDeviceAlias() }
        lease?.let { deleteLease(it) } ?: log.w("No lease with current device alias found")
    }

}