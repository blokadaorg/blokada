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

package ui

import androidx.lifecycle.*
import kotlinx.coroutines.launch
import model.AdsCounter
import service.PersistenceService
import utils.Logger

class AdsCounterViewModel: ViewModel() {

    private val log = Logger("AdsCounter")
    private val persistence = PersistenceService

    private val _counter = MutableLiveData<AdsCounter>()
    val counter: LiveData<Long> = _counter.distinctUntilChanged().map { it.get() }

    init {
        viewModelScope.launch {
            var counter = persistence.load(AdsCounter::class)
            if (counter.runtimeValue != 0L) {
                log.w("Rolling ads counter loaded from persistence")
                counter = counter.roll()
            }
            _counter.value = counter
        }
    }

    fun setRuntimeCounter(counter: Long) {
        viewModelScope.launch {
            _counter.value?.let {
                val new = it.copy(runtimeValue = counter)
                persistence.save(new)
                _counter.value = new
            }
        }
    }

    fun roll() {
        viewModelScope.launch {
            _counter.value?.let {
                log.v("Rolling ads counter: ${it.get()}")
                val new = it.roll()
                persistence.save(new)
                _counter.value = new
            }
        }
    }

}