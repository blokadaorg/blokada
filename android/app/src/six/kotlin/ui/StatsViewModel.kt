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
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch
import model.*
import repository.Repos
import service.EnvironmentService
import utils.FlavorSpecific

class StatsViewModel : ViewModel(), FlavorSpecific {

    enum class Sorting {
        RECENT, TOP
    }

    enum class Filter {
        ALL, BLOCKED, ALLOWED
    }

    private val activityRepo by lazy { Repos.activity }

    private var sorting = Sorting.RECENT
    private var filter = Filter.ALL
    private var searchTerm: String? = null
    private var device: String? = EnvironmentService.getDeviceAlias()

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
            activityRepo.entriesHot
            .collect {
                _stats.value = Stats(
                    allowed = 0,
                    denied = 0,
                    entries = it
                )
                updateLiveData()
            }
        }

        viewModelScope.launch {
            activityRepo.allowedListHot
            .collect {
                _allowed.value = Allowed(it)
            }
        }

        viewModelScope.launch {
            activityRepo.deniedListHot
            .collect {
                _denied.value = Denied(it)
            }
        }
    }

    fun refresh() {
        viewModelScope.launch {
            activityRepo.refresh()
        }
    }

    fun clear() {
        refresh()
    }

    fun get(forName: String): HistoryEntry? {
        return history.value?.firstOrNull { it.name == forName }
    }

    fun getFilter() = filter
    fun getSorting() = sorting
    fun getSearch() = searchTerm
    fun getDevice() = device

    fun filter(filter: Filter) {
        this.filter = filter
        GlobalScope.launch { activityRepo.refresh() }
    }

    fun sort(sort: Sorting) {
        this.sorting = sort
        GlobalScope.launch { activityRepo.refresh() }
    }

    fun search(search: String?) {
        this.searchTerm = search
        updateLiveData()
    }

    fun device(device: String?) {
        this.device = device
        GlobalScope.launch { activityRepo.refresh() }
    }

    fun allow(name: String) {
        viewModelScope.launch {
            activityRepo.allow(name)
        }
    }

    fun unallow(name: String) {
        viewModelScope.launch {
            activityRepo.unallow(name)
        }
    }

    fun deny(name: String) {
        viewModelScope.launch {
            activityRepo.deny(name)
        }
    }

    fun undeny(name: String) {
        viewModelScope.launch {
            activityRepo.undeny(name)
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

        // Apply device filtering
        device?.run {
            entries = entries.filter { it.device == this }
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