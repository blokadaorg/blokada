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

package service

import kotlinx.coroutines.coroutineScope
import model.HistoryEntry
import model.HistoryEntryType
import model.Stats
import engine.Host
import kotlinx.coroutines.launch
import java.util.*

object StatsService {

    private var runtimeAllowed = 0
    private var runtimeDenied = 0
    private val internalStats: MutableMap<InternalKey, InternalEntry> = mutableMapOf()

    suspend fun passedAllowed(host: Host) {
        increment(host, HistoryEntryType.passed_allowed)
        runtimeAllowed += 1
    }

    suspend fun blockedDenied(host: Host) {
        increment(host, HistoryEntryType.blocked_denied)
        runtimeDenied += 1
    }

    suspend fun blocked(host: Host) {
        increment(host, HistoryEntryType.blocked)
        runtimeDenied += 1
    }

    suspend fun passed(host: Host) {
        increment(host, HistoryEntryType.passed)
        runtimeAllowed += 1
    }

    suspend fun getStats(): Stats {
        return coroutineScope {
            Stats(
                allowed = runtimeAllowed,
                denied = runtimeAllowed,
                entries = internalStats.map {
                    HistoryEntry(
                        name = it.key.host,
                        type = it.key.type,
                        time = Date(it.value.lastEncounter),
                        requests = it.value.occurrences
                    )
                }
            )
        }
    }

    private suspend fun increment(host: Host, type: HistoryEntryType) {
        coroutineScope {
            val key = InternalKey(host, type)
            val entry = internalStats.getOrElse(key, {
                InternalEntry(lastEncounter = System.currentTimeMillis(), occurrences = 0)
            })
            entry.lastEncounter = System.currentTimeMillis()
            entry.occurrences += 1
            internalStats[key] = entry

//            launch {
//                 XXX: not the best place, but we want realtime notification updates
//                MonitorService.setStats(getStats())
//            }
        }
    }

}

private data class InternalKey(
    val host: Host,
    val type: HistoryEntryType
)

private class InternalEntry(
    var lastEncounter: Long,
    var occurrences: Int
)
