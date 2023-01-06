/*
 * This file is part of Blokada.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Copyright © 2022 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package repository

import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import model.CustomListEntry
import model.HistoryEntry
import model.Tab
import service.Services
import ui.stats.convertActivity
import utils.Ignored
import utils.SimpleTasker
import utils.Tasker


class ActivityRepo {

    // Ensure they emit on same value
    private val writeEntries = MutableSharedFlow<List<HistoryEntry>?>()
    private val writeCustomList = MutableSharedFlow<List<CustomListEntry>?>(replay = 1)

    val entriesHot = writeEntries.filterNotNull()

    val allowedListHot = writeCustomList.filterNotNull().map { c ->
        c.filter { it.action == "allow" }.map { it.domain_name }
    }

    val deniedListHot = writeCustomList.filterNotNull().map { c ->
        c.filter { it.action == "block" }.map { it.domain_name }
    }

    val customList = writeCustomList.filterNotNull()

    var devicesHot = entriesHot.map { e -> e.map { it.device } }

    private val api = Services.apiForCurrentUser

    private val activeTabHot by lazy { Repos.nav.activeTabHot }

    private val fetchEntriesT = SimpleTasker<Ignored>("fetchEntries")
    private val fetchCustomListT = SimpleTasker<Ignored>("fetchCustomList")
    private val updateCustomListT = Tasker<CustomListEntry, Ignored>("updateCustomList")

    fun start() {
        onFetchEntries()
        onFetchCustomList()
        onUpdateCustomList()
        onActivityTab_RefreshActivity()
    }

    suspend fun allow(entry: String) {
        updateCustomListT.send(CustomListEntry(
            domain_name = entry,
            action = "allow"
        ))
    }

    suspend fun unallow(entry: String) {
        updateCustomListT.send(CustomListEntry(
            domain_name = entry,
            action = "fallthrough"
        ))
    }

    suspend fun deny(entry: String) {
        updateCustomListT.send(CustomListEntry(
            domain_name = entry,
            action = "block"
        ))
    }

    suspend fun undeny(entry: String) = unallow(entry)

    suspend fun refresh() {
        fetchEntriesT.send()
        fetchCustomListT.send()
    }

    private fun onFetchEntries() {
        fetchEntriesT.setTask {
            val activity = api.getActivityForCurrentUserAndDevice()
            val converted = convertActivity(activity)
            writeEntries.emit(converted)
            true
        }
    }

    private fun onFetchCustomList() {
        fetchCustomListT.setTask {
            val custom = api.getCustomListForCurrentUser()
            writeCustomList.emit(custom)
            true
        }
    }

    private fun onUpdateCustomList() {
        updateCustomListT.setTask { entry ->
            // Post the custom list update to backend
            if (entry.action == "fallthrough") {
                api.deleteCustomListForCurrentUser(entry.domain_name)
            } else {
                api.postCustomListForCurrentUser(entry)
            }

            // Update our local cache for quick UX
            val updated = customList.first().map {
                if (it.domain_name == entry.domain_name) {
                    entry
                } else {
                    it
                }
            }
            writeCustomList.emit(updated)

            // But also issue a get request to get in sync
            fetchCustomListT.get()
            fetchEntriesT.get()

            true
        }
    }

    private fun onActivityTab_RefreshActivity() {
        GlobalScope.launch {
            activeTabHot.filter { it == Tab.Activity }
            .collect {
                refresh()
            }
        }
    }

}