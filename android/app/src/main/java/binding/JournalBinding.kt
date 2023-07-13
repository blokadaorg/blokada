/*
 * This file is part of Blokada.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Copyright © 2023 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package binding

import androidx.lifecycle.MutableLiveData
import channel.command.CommandName
import channel.journal.JournalEntry
import channel.journal.JournalFilter
import channel.journal.JournalFilterType
import channel.journal.JournalOps
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.launch
import service.FlutterService
import utils.toBlockaDate
import java.util.Date

data class UiJournalEntry(
    //val id: String,
    val time: Date,
    val entry: JournalEntry,
)

val defaultFilter = JournalFilter(JournalFilterType.ALL, "", "", true)

object JournalBinding: JournalOps {
    val entries = MutableStateFlow<List<UiJournalEntry>>(emptyList())
    val filter = MutableStateFlow(defaultFilter)
    val devices = MutableStateFlow<List<String>>(emptyList())

    val entriesLive = MutableLiveData<List<UiJournalEntry>>()
    val filterLive = MutableLiveData<JournalFilter>()

    private val flutter by lazy { FlutterService }
    private val command by lazy { CommandBinding }

    private val scope = GlobalScope

    init {
        JournalOps.setUp(flutter.engine.dartExecutor.binaryMessenger, this)
        scope.launch {
            entries.collect { entriesLive.postValue(it) }
        }
        scope.launch {
            filter.collect { filterLive.postValue(it) }
        }
    }

    fun get(name: String): UiJournalEntry? {
        // TODO: risky, better by id
        return entries.value.firstOrNull { it.entry.domainName == name }
    }

    fun sort(newestFirst: Boolean) {
        scope.launch {
            if (newestFirst) command.execute(CommandName.SORTNEWEST)
            else command.execute(CommandName.SORTCOUNT)
        }
    }

    fun search(query: String) {
        scope.launch {
            command.execute(CommandName.SEARCH, query)
        }
    }

    fun filter(filter: JournalFilterType) {
        scope.launch {
            command.execute(CommandName.FILTER, filter.name.lowercase())
        }
    }

    fun filterDevice(device: String) {
        scope.launch {
            command.execute(CommandName.FILTERDEVICE, device)
        }
    }

    override fun doReplaceEntries(entries: List<JournalEntry>, callback: (Result<Unit>) -> Unit) {
        this.entries.value = entries.map { UiJournalEntry(it.time.toBlockaDate(), it) }
        callback(Result.success(Unit))
    }

    override fun doFilterChanged(filter: JournalFilter, callback: (Result<Unit>) -> Unit) {
        this.filter.value = filter
        callback(Result.success(Unit))
    }

    override fun doDevicesChanged(devices: List<String>, callback: (Result<Unit>) -> Unit) {
        this.devices.value = devices
        callback(Result.success(Unit))
    }

    override fun doHistoricEntriesAvailable(
        entries: List<JournalEntry>,
        callback: (Result<Unit>) -> Unit
    ) {
        // TODO: not implemented
        callback(Result.success(Unit))
    }
}