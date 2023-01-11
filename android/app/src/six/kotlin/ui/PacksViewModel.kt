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

import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.ViewModel
import androidx.lifecycle.map
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch
import model.Pack
import model.PackConfig
import model.Packs
import repository.Repos
import service.AlertDialogService
import utils.FlavorSpecific

class PacksViewModel : ViewModel(), FlavorSpecific {

    enum class Filter {
        HIGHLIGHTS, ACTIVE, ALL
    }

    private val packsRepo by lazy { Repos.packs }
    private val alert = AlertDialogService

    private val activeTags = listOf("official")
    private var filter = Filter.HIGHLIGHTS

    private val _packs = MutableLiveData<Packs>()
    val packs = _packs.map { applyFilters(it.packs) }

    init {
        viewModelScope.launch {
            packsRepo.packsHot
            .collect {
                _packs.value = Packs(it, 0, 0)
                updateLiveData()
            }
        }
    }

    suspend fun setup() {
    }

    fun get(packId: String): Pack? {
        return _packs.value?.packs?.firstOrNull { it.id == packId }
    }

    fun filter(filter: Filter) {
        this.filter = filter
        updateLiveData()
    }

    fun getFilter() = filter

    fun changeConfig(pack: Pack, config: PackConfig) {
        viewModelScope.launch {
            packsRepo.changeConfig(pack, config)
        }
    }

    fun install(pack: Pack) {
        viewModelScope.launch {
            packsRepo.installPack(pack)
        }
    }

    fun uninstall(pack: Pack) {
        viewModelScope.launch {
            packsRepo.uninstallPack(pack)
        }
    }

    private fun updateLiveData() {
        viewModelScope.launch {
            // This will cause to emit new event and to refresh the public LiveData
            _packs.value = _packs.value
        }
    }

    private fun applyFilters(allPacks: List<Pack>): List<Pack> {
        return when (filter) {
            Filter.ACTIVE -> {
                allPacks.filter { pack ->
                    pack.status.installed
                }
            }
            Filter.ALL -> {
                allPacks.filter { pack ->
                    activeTags.intersect(pack.tags).isEmpty() != true
                }
            }
            else -> {
                allPacks.filter { pack ->
                    pack.tags.contains(Pack.recommended) /* && !pack.status.installed */
                }
            }
        }
    }

}
