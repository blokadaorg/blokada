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

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.PowerManager
import model.BlokadaException
import utils.Logger

object DozeService {

    private val log = Logger("doze")
    private lateinit var powerManager: PowerManager

    var onDozeChanged = { isDoze: Boolean -> }

    fun setup(ctx: Context) {
        ctx.registerReceiver(DozeReceiver(), IntentFilter(PowerManager.ACTION_DEVICE_IDLE_MODE_CHANGED))
        powerManager = ctx.getSystemService(Context.POWER_SERVICE) as PowerManager
        log.v("Registered DozeReceiver")
    }

    fun isDoze() = powerManager.isDeviceIdleMode

    internal fun dozeChanged() {
        val doze = powerManager.isDeviceIdleMode
        log.v("Doze changed: $doze")
        onDozeChanged(doze)
    }

    fun ensureNotDoze() {
        if (isDoze()) throw BlokadaException("Doze mode detected")
    }
}

class DozeReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, p1: Intent) {
        ContextService.setContext(ctx)
        DozeService.dozeChanged()
    }
}
