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

import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import model.AppState
import org.blokada.R
import repository.Repos
import utils.FlavorSpecific
import utils.Logger

class QuickSettingsToggle : TileService(), FlavorSpecific {

    private val log = Logger("QSTile")

    private val appRepo by lazy { Repos.app }

    private var tileActive = false

    init {
        GlobalScope.launch {
            appRepo.appStateHot.collect { syncStatus(state = it) }
        }

        GlobalScope.launch {
            appRepo.workingHot.collect { syncStatus(working = it) }
        }
    }

    override fun onStartListening() {
        tileActive = true
        GlobalScope.launch { syncStatus() }
    }

    override fun onStopListening() {
        tileActive = false
    }

    override fun onTileAdded() {
        GlobalScope.launch { syncStatus() }
    }

    override fun onClick() {
        GlobalScope.launch {
            syncStatus()?.let { isActive ->
                if (isActive) {
                    log.v("Turning off from QuickSettings")
                    executeCommand(Command.OFF)
                } else {
                    log.v("Turning on from QuickSettings")
                    executeCommand(Command.ON)
                }
            }
        }
    }

    private suspend fun syncStatus(state: AppState? = null, working: Boolean? = null): IsActive? {
        val state = state ?: appRepo.appStateHot.first()
        val working = working ?: appRepo.workingHot.first()

        return when {
            qsTile == null -> null
            working -> {
                showActivating()
                null
            }
            state == AppState.Activated -> {
                showOn()
                true
            }
            else -> {
                showOff()
                false
            }
        }
    }

    private fun showActivating() {
        qsTile.state = Tile.STATE_ACTIVE
        qsTile.label = "..."
        qsTile.updateTile()
    }

    private fun showOff() {
        qsTile.state = Tile.STATE_INACTIVE
        qsTile.label = getString(R.string.home_status_deactivated)
        qsTile.updateTile()
    }

    private fun showOn() {
        qsTile.state = Tile.STATE_ACTIVE
        qsTile.label = getString(R.string.home_status_active)
        qsTile.updateTile()
    }

}

private typealias IsActive = Boolean