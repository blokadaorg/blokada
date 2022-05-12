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
import model.BlokadaException
import model.ComponentError
import model.ComponentOngoing
import utils.Logger

open class ProcessingRepo {

    private val writeOngoing = MutableSharedFlow<ComponentOngoing?>()
    private val writeError = MutableSharedFlow<ComponentError?>()

    val ongoingHot = writeOngoing.filterNotNull().distinctUntilChanged()
    val errorsHot = writeError.filterNotNull().distinctUntilChanged()

    open fun start() {}

    val currentlyOngoingHot = ongoingHot.scan(emptyList<ComponentOngoing>()) { acc, p ->
        if (p.ongoing && !acc.any { it.component == p.component }) {
            acc + listOf(p)
        } else if (!p.ongoing && acc.any { it.component == p.component }) {
            acc.filter { it.component != p.component }
        } else {
            acc
        }
    }.distinctUntilChanged()

    suspend fun notify(component: Any, ex: BlokadaException, major: Boolean) {
        writeError.emit(ComponentError("$component", ex, major))
        notify(component, ongoing = false)
    }

    suspend fun notify(component: Any, ongoing: Boolean) {
        writeOngoing.emit(ComponentOngoing("$component", ongoing))
    }

}

class DebugProcessingRepo: ProcessingRepo() {

    override fun start() {
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
    }

}