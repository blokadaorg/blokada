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
import model.*
import utils.Logger

open class ProcessingRepo {

    private val writeOngoing = MutableSharedFlow<ComponentOngoing?>()
    private val writeError = MutableSharedFlow<ComponentError?>()
    internal val writeConnIssues = MutableSharedFlow<Set<Any>>(replay = 1)

    private val ongoingHot = writeOngoing.filterNotNull().distinctUntilChanged()
    val errorsHot = writeError.filterNotNull().distinctUntilChanged()
    val connIssuesHot = writeConnIssues.map { it.isNotEmpty() }.distinctUntilChanged()

    internal val recentTimeoutsHot = writeError.scan(emptyList<ComponentTimeout>()) { acc, p ->
        if (p == null) {
            acc
        } else if (p.error !is TimeoutException) {
            // Remove old timeouts
            acc.filter { it.timeoutMillis + 30 * 1000 >= System.currentTimeMillis() }
        } else if (acc.any { it.component == p.component }) {
            // Replace timeout of recently timed-out task with a newer timestamp
            acc.filter { it.component != p.component }.plus(
                ComponentTimeout(p.component, System.currentTimeMillis())
            )
        } else {
            // Add this task to timeouts timestamps
            acc + ComponentTimeout(p.component, System.currentTimeMillis())
        }
    }.distinctUntilChanged()

    val currentlyOngoingHot = ongoingHot.scan(emptyList<ComponentOngoing>()) { acc, p ->
        if (p.ongoing && !acc.any { it.component == p.component }) {
            acc + listOf(p)
        } else if (!p.ongoing && acc.any { it.component == p.component }) {
            acc.filter { it.component != p.component }
        } else {
            acc
        }
    }.distinctUntilChanged()

    open fun start() {
        GlobalScope.launch { writeConnIssues.emit(emptySet()) }
        onManyRecentTimeouts_ReportConnIssue()
    }

    suspend fun notify(component: Any, ex: BlokadaException, major: Boolean) {
        writeError.emit(ComponentError("$component", ex, major))
        notify(component, ongoing = false)
    }

    suspend fun notify(component: Any, ongoing: Boolean) {
        writeOngoing.emit(ComponentOngoing("$component", ongoing))
    }

    suspend fun reportConnIssues(component: Any, experiencing: Boolean) {
        val current = writeConnIssues.first()
        if (experiencing) writeConnIssues.emit(current + component)
        else writeConnIssues.emit(current - component)
    }

    private fun onManyRecentTimeouts_ReportConnIssue() {
        GlobalScope.launch {
            recentTimeoutsHot.collect {
                reportConnIssues("timeout", it.size > 3)
            }
        }
    }

}

class DebugProcessingRepo: ProcessingRepo() {

    override fun start() {
        super.start()

        GlobalScope.launch {
            errorsHot.collect {
                if (it.major)
                    Logger.e("Processing", "Major error: ${it.component}: ${it.error}")
                else
                    Logger.w("Processing", "Error: ${it.component}: ${it.error}")
            }
        }

        GlobalScope.launch {
            currentlyOngoingHot.collect {
                Logger.v("Processing", "$it")
            }
        }

        GlobalScope.launch {
            writeConnIssues.distinctUntilChanged().collect {
                Logger.v("Processing", "ConnIssues: $it")
            }
        }

        GlobalScope.launch {
            recentTimeoutsHot.distinctUntilChanged().collect {
                Logger.v("Processing", "Timeout: $it")
            }
        }
    }

}