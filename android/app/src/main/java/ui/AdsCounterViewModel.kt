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