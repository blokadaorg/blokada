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

package ui.settings.leases

import androidx.lifecycle.*
import kotlinx.coroutines.launch
import model.*
import engine.EngineService
import service.LeaseService
import ui.utils.cause
import utils.Logger
import java.lang.Exception

class LeasesViewModel : ViewModel() {

    private val log = Logger("Settings")
    private val blocka = LeaseService
    private val engine = EngineService

    private val _leases = MutableLiveData<List<Lease>>()
    val leases = _leases as LiveData<List<Lease>>

    fun fetch(accountId: AccountId) {
        viewModelScope.launch {
            try {
                _leases.value = blocka.fetchLeases(accountId)
            } catch (ex: Exception) {
                log.w("Could not fetch leases".cause(ex))
            }
        }
    }

    fun delete(accountId: AccountId, lease: Lease) {
        log.w("Deleting lease: ${lease.alias}")
        viewModelScope.launch {
            try {
                blocka.deleteLease(lease)
            } catch (ex: Exception) {
                log.w("Could not delete lease".cause(ex))
            }
            fetch(accountId)
        }
    }

}