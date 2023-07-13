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
import binding.AppBinding
import binding.isActive
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import org.blokada.R
import utils.FlavorSpecific
import utils.Logger

class QuickSettingsToggle : TileService(), FlavorSpecific {

    private val log = Logger("QSTile")
    private val app by lazy { AppBinding }

    private var tileActive = false

    init {
        GlobalScope.launch {
            app.appStatus.collect { syncStatus() }
        }

        GlobalScope.launch {
            app.working.collect { syncStatus() }
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

    private suspend fun syncStatus(): IsActive? {
        val state = app.appStatus.first()
        val working = app.working.first()

        return when {
            qsTile == null -> null
            working == true -> {
                showActivating()
                null
            }
            state.isActive() -> {
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