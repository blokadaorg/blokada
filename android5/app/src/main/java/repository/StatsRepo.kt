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
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import model.CounterStats
import service.Services
import utils.Ignored
import utils.SimpleTasker


class StatsRepo {

    private val writeStats = MutableStateFlow<CounterStats?>(null)

    val statsHot = writeStats.filterNotNull()
    val blockedHot = statsHot.map { it.total_blocked.toLong() }

    private val api = Services.apiForCurrentUser

    private val accountIdHot by lazy { Repos.account.accountIdHot }
    private val enteredForegroundHot by lazy { Repos.stage.enteredForegroundHot }
    private val activityEntriesHot by lazy { Repos.activity.entriesHot }

    private val refreshStatsT = SimpleTasker<Ignored>("refreshStats")

    fun start() {
        onRefreshStats()
        onAccountIdChange_refreshStats()
        onForeground_refreshStats()
        onActivityChanged_refreshStats()
    }

    private fun onRefreshStats() {
        refreshStatsT.setTask {
            val stats = api.getStatsForCurrentUser()
            writeStats.emit(stats)
            true
        }
    }

    // Refresh on account ID changed, will also trigger when starting the app
    private fun onAccountIdChange_refreshStats() {
        GlobalScope.launch {
            accountIdHot
            .collect {
                refreshStatsT.send()
            }
        }
    }

    private fun onForeground_refreshStats() {
        GlobalScope.launch {
            enteredForegroundHot
            .collect {
                refreshStatsT.send()
            }
        }
    }

    private fun onActivityChanged_refreshStats() {
        GlobalScope.launch {
            activityEntriesHot
            .collect {
                refreshStatsT.send()
            }
        }
    }

}