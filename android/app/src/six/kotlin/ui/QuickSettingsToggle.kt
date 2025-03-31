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
import binding.isWorking
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import org.blokada.R
import utils.FlavorSpecific
import utils.Logger

class QuickSettingsToggle : TileService(), FlavorSpecific {

    private val log = Logger("QSTile")
    private val app by lazy { AppBinding }
    private val scope by lazy { CoroutineScope(Dispatchers.Main) }

    private var tileActive = false

    init {
        scope.launch {
            app.appStatus.collect { syncStatus() }
        }
    }

    override fun onStartListening() {
        tileActive = true
        scope.launch { syncStatus() }
    }

    override fun onStopListening() {
        tileActive = false
    }

    override fun onTileAdded() {
        scope.launch { syncStatus() }
    }

    override fun onClick() {
        scope.launch {
            syncStatus()?.let { isActive ->
                if (isActive) {
                    log.v("Turning off from QuickSettings")
                    app.pause()
                } else {
                    log.v("Turning on from QuickSettings")
                    app.unpause()
                }
            }
        }
    }

    private suspend fun syncStatus(): IsActive? {
        val state = app.appStatus.first()
        val tile = qsTile

        return when {
            tile == null -> null
            state.isWorking() -> {
                showWorking(tile)
                true
            }

            state.isActive() -> {
                showOn(tile)
                true
            }

            else -> {
                showOff(tile)
                false
            }
        }
    }

    private fun showOff(qsTile: Tile) {
        qsTile.state = Tile.STATE_INACTIVE
        qsTile.label = getString(R.string.home_status_deactivated)
        updateTile(qsTile)
    }

    private fun showOn(qsTile: Tile) {
        qsTile.state = Tile.STATE_ACTIVE
        qsTile.label = getString(R.string.home_status_active)
        updateTile(qsTile)
    }

    private fun showWorking(qsTile: Tile) {
        qsTile.state = Tile.STATE_ACTIVE
        qsTile.label = getString(R.string.home_status_detail_progress)
        updateTile(qsTile)
    }

    // Apparently it can crash for unknown reasons
    private fun updateTile(gsTile: Tile) {
        try {
            qsTile.updateTile()
        } catch (ex: Exception) {
        }
    }
}

private typealias IsActive = Boolean