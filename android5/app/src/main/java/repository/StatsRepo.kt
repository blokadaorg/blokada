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
        GlobalScope.launch { onRefreshStats() }
        GlobalScope.launch { onAccountIdChange_refreshStats() }
        GlobalScope.launch { onForeground_refreshStats() }
        GlobalScope.launch { onActivityChanged_refreshStats() }
    }

    private suspend fun onRefreshStats() {
        refreshStatsT.setTask {
            val stats = api.getStatsForCurrentUser()
            writeStats.emit(stats)
            true
        }
    }

    // Refresh on account ID changed, will also trigger when starting the app
    private suspend fun onAccountIdChange_refreshStats() {
        accountIdHot
        .collect {
            refreshStatsT.send()
        }
    }

    private suspend fun onForeground_refreshStats() {
        enteredForegroundHot
        .collect {
            refreshStatsT.send()
        }
    }

    private suspend fun onActivityChanged_refreshStats() {
        activityEntriesHot
        .collect {
            refreshStatsT.send()
        }
    }

}