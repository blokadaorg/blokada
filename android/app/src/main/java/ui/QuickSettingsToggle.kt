/*
 * This file is part of Blokada.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Copyright © 2025 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package ui

import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import binding.AppBinding
import binding.isActive
import binding.isWorking
import channel.app.AppStatus
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import org.blokada.R
import service.NOTIF_QUICKSETTINGS
import service.NotificationService
import utils.FlavorSpecific
import utils.Logger
import utils.QuickSettingsNotification

private typealias IsActive = Boolean
private typealias IsVpn = Boolean

class QuickSettingsToggle : TileService(), FlavorSpecific {

    private val log = Logger("QSTile")
    private val app by lazy { AppBinding }
    private val scope by lazy { CoroutineScope(Dispatchers.Main) }
    private val notification by lazy { NotificationService }

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
            syncStatus()?.let { (isActive, isVpn) ->
                if (isActive) {
                    log.v("Turning off from QuickSettings")
                    app.pause()
                    if (isVpn) notification.show(QuickSettingsNotification())
                } else {
                    log.v("Turning on from QuickSettings")
                    notification.cancel(QuickSettingsNotification())
                    app.unpause()
                }
            }
        }
    }

    private suspend fun syncStatus(): Pair<IsActive, IsVpn>? {
        val state = app.appStatus.first()
        val tile = qsTile

        return when {
            tile == null -> null
            state.isWorking() -> {
                showWorking(tile)
                true to false
            }

            state.isActive() -> {
                showOn(tile)
                val isVpn = state == AppStatus.ACTIVATEDPLUS
                true to isVpn
            }

            else -> {
                showOff(tile)
                false to false
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