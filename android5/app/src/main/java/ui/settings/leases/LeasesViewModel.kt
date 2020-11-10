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