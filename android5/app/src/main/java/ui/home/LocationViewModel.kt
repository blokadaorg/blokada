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

package ui.home

import androidx.lifecycle.*
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import model.Gateway
import repository.BlockaRepository
import repository.LocationRepository
import ui.utils.cause
import utils.Logger
import java.lang.Exception

class LocationViewModel : ViewModel() {

    private val blocka = BlockaRepository

    private val _locations = MutableLiveData<List<Gateway>>()
    val locations: LiveData<List<Gateway>> = _locations.distinctUntilChanged()

    fun refreshLocations() {
        viewModelScope.launch {
            try {
                _locations.value = blocka.fetchGateways()
            } catch (ex: Exception) {
                Logger.w("Location", "Could not load locations".cause(ex))
            }
        }
    }

}