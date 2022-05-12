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
import engine.EngineService
import kotlinx.coroutines.launch
import model.*
import service.EnvironmentService
import service.PersistenceService
import service.StatsService
import ui.utils.cause
import utils.FlavorSpecific
import utils.Logger

class StatsViewModel : ViewModel(), FlavorSpecific {

    enum class Sorting {
        RECENT, TOP
    }

    enum class Filter {
        ALL, BLOCKED, ALLOWED
    }

    private val log = Logger("Stats")
    private val persistence = PersistenceService
    private val engine = EngineService
    private val statistics = StatsService

    private var sorting = Sorting.RECENT
    private var filter = Filter.ALL
    private var searchTerm: String? = null

    private val _stats = MutableLiveData<Stats>()
    val stats: LiveData<Stats> = _stats.distinctUntilChanged()
    val history = _stats.map {
        applyFilters(it.entries)
    }

    private val _allowed = MutableLiveData<Allowed>()
    val allowed = _allowed.map { it.value }

    private val _denied = MutableLiveData<Denied>()
    val denied = _denied.map { it.value }

    init {
        viewModelScope.launch {
            _allowed.value = persistence.load(Allowed::class)
            _denied.value = persistence.load(Denied::class)
            statistics.setup()
        }
    }

    fun refresh() {
        viewModelScope.launch {
            try {
                _stats.value = statistics.getStats()
                _allowed.value = _allowed.value
                _denied.value = _denied.value
            } catch (ex: Exception) {
                log.e("Could not load stats".cause(ex))
            }
        }
    }

    fun clear() {
        statistics.clear()
        refresh()
    }

    fun get(forName: String): HistoryEntry? {
        return history.value?.firstOrNull { it.name == forName }
    }

    fun getFilter() = filter
    fun getSorting() = sorting
    fun getSearch() = searchTerm

    // Mocked getters to be compatible with NotLibre flavor
    fun getDevice() = EnvironmentService.getDeviceAlias()
    fun device(device: String?) = {}

    fun filter(filter: Filter) {
        this.filter = filter
        updateLiveData()
    }

    fun sort(sort: Sorting) {
        this.sorting = sort
        updateLiveData()
    }

    fun search(search: String?) {
        this.searchTerm = search
        updateLiveData()
    }

    fun allow(name: String) {
        _allowed.value?.let { current ->
            viewModelScope.launch {
                try {
                    val new = current.allow(name)
                    persistence.save(new)
                    _allowed.value = new
                    updateLiveData()
                    engine.reloadBlockLists()
                } catch (ex: Exception) {
                    log.e("Could not allow host $name".cause(ex))
                    persistence.save(current)
                }
            }
        }
    }

    fun unallow(name: String) {
        _allowed.value?.let { current ->
            viewModelScope.launch {
                try {
                    val new = current.unallow(name)
                    persistence.save(new)
                    _allowed.value = new
                    updateLiveData()
                    engine.reloadBlockLists()
                } catch (ex: Exception) {
                    log.e("Could not unallow host $name".cause(ex))
                    persistence.save(current)
                }
            }
        }
    }

    fun deny(name: String) {
        _denied.value?.let { current ->
            viewModelScope.launch {
                try {
                    val new = current.deny(name)
                    persistence.save(new)
                    _denied.value = new
                    updateLiveData()
                    engine.reloadBlockLists()
                } catch (ex: Exception) {
                    log.e("Could not deny host $name".cause(ex))
                    persistence.save(current)
                }
            }
        }
    }

    fun undeny(name: String) {
        _denied.value?.let { current ->
            viewModelScope.launch {
                try {
                    val new = current.undeny(name)
                    persistence.save(new)
                    _denied.value = new
                    updateLiveData()
                    engine.reloadBlockLists()
                } catch (ex: Exception) {
                    log.e("Could not undeny host $name".cause(ex))
                    persistence.save(current)
                }
            }
        }
    }

    fun isAllowed(name: String): Boolean {
        return _allowed.value?.value?.contains(name) ?: false
    }

    fun isDenied(name: String): Boolean {
        return _denied.value?.value?.contains(name) ?: false
    }

    private fun updateLiveData() {
        viewModelScope.launch {
            // This will cause to emit new event and to refresh the public LiveData
            _stats.value = _stats.value
        }
    }

    private fun applyFilters(history: List<HistoryEntry>): List<HistoryEntry> {
        var entries = history

        // Apply search term
        searchTerm?.run {
            entries = history.filter { it.name.contains(this, ignoreCase = true) }
        }

        // Apply filtering
        when (filter) {
            Filter.BLOCKED -> {
                // Show blocked and denied hosts only
                entries = entries.filter { it.type == HistoryEntryType.blocked || it.type == HistoryEntryType.blocked_denied }
            }
            Filter.ALLOWED -> {
                // Show allowed and bypassed hosts only
                entries = entries.filter { it.type != HistoryEntryType.blocked && it.type != HistoryEntryType.blocked_denied }
            }
            else -> {}
        }

        // Apply sorting
        return when(sorting) {
            Sorting.TOP -> {
                // Sorted by the number of requests
                entries.sortedByDescending { it.requests }
            }
            Sorting.RECENT -> {
                // Sorted by recent
                entries.sortedByDescending { it.time }
            }
        }
    }

}