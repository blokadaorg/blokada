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

package engine

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import service.BlocklistService
import service.StatsService
import utils.Logger

internal object FilteringService {

    private val log = Logger("Filtering")
    private val blocklist = BlocklistService
    private val stats = StatsService
    private val scope = GlobalScope

    private var merged = emptyList<Host>()
    private var userAllowed = emptyList<Host>()
    private var userDenied = emptyList<Host>()

    fun reload() {
        log.v("Reloading blocklist")
        merged = blocklist.loadMerged()
        userAllowed = blocklist.loadUserAllowed()
        userDenied = blocklist.loadUserDenied()
        log.v("Reloaded: ${merged.size} hosts, + user: ${userDenied.size} denied, ${userAllowed.size} allowed")
    }

    fun allowed(host: Host): Boolean {
        return if (userAllowed.contains(host)) {
            scope.launch(Dispatchers.Main) { stats.passedAllowed(host) }
            true
        } else false
    }

    fun denied(host: Host): Boolean {
        return if (userDenied.contains(host)) {
            scope.launch(Dispatchers.Main) { stats.blockedDenied(host) }
            true
        } else if (merged.contains(host)) {
            scope.launch(Dispatchers.Main) { stats.blocked(host) }
            true
        } else {
            scope.launch(Dispatchers.Main) { stats.passed(host) }
            false
        }
    }

}

typealias Host = String
