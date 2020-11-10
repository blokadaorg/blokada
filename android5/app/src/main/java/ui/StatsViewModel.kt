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
import model.*
import engine.EngineService
import service.PersistenceService
import service.StatsService
import ui.utils.cause
import utils.Logger
import java.lang.Exception

class StatsViewModel : ViewModel() {

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

    fun get(forName: String): HistoryEntry? {
        return history.value?.firstOrNull { it.name == forName }
    }

    fun getFilter() = filter
    fun getSorting() = sorting

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
                // Blocked only
                entries = entries.filter { it.type == HistoryEntryType.blocked }
            }
            Filter.ALLOWED -> {
                // Allowed only
                entries = entries.filter { it.type != HistoryEntryType.blocked }
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