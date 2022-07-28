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
import androidx.lifecycle.ViewModelProvider
import model.TunnelStatus
import org.blokada.R
import utils.FlavorSpecific
import utils.Logger

class QuickSettingsToggle : TileService(), FlavorSpecific {

    private val log = Logger("QSTile")

    private val vm by lazy {
        val vm = ViewModelProvider(app()).get(TunnelViewModel::class.java)
        vm.tunnelStatus.observeForever {
            if (tileActive) {
                syncStatus(it)
            }
        }
        vm
    }

    private var tileActive = false

    override fun onStartListening() {
        tileActive = true
        syncStatus()
    }

    override fun onStopListening() {
        tileActive = false
    }

    override fun onTileAdded() {
        syncStatus()
    }

    override fun onClick() {
        syncStatus()?.let { isActive ->
            if (isActive) {
                log.v("Turning off from QuickSettings")
                vm.turnOff()
            } else {
                log.v("Turning on from QuickSettings")
                vm.turnOn()
            }
        }
    }

    private fun syncStatus(status: TunnelStatus? = vm.tunnelStatus.value): IsActive? {
        return when {
            qsTile == null -> null
            status == null -> {
                showOff()
                false
            }
            status.inProgress -> {
                showActivating()
                null
            }
            status.active -> {
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