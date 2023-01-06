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

package engine

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import service.ContextService
import utils.Logger

object ScreenOnService {

    private val ctx by lazy { ContextService }

    private val frequencyMillis = 200
    private var lastScreenOffMillis = 0L

    var onScreenOn = {}

    var isScreenOn = true
        @Synchronized get
        @Synchronized set

    init {
        val intentFilter = IntentFilter(Intent.ACTION_SCREEN_ON)
        intentFilter.addAction(Intent.ACTION_SCREEN_OFF)
        val mReceiver: BroadcastReceiver = ScreenStateBroadcastReceiver()
        ctx.requireAppContext().registerReceiver(mReceiver, intentFilter)
        Logger.v("ScreenOn", "Registered for Screen ON")
    }

    class ScreenStateBroadcastReceiver: BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                Intent.ACTION_SCREEN_OFF -> {
                    lastScreenOffMillis = System.currentTimeMillis()
                    isScreenOn = false
                }
                Intent.ACTION_SCREEN_ON -> {
                    isScreenOn = true
                    if (lastScreenOffMillis + frequencyMillis < System.currentTimeMillis()) {
                        Logger.v("ScreenOn", "Received Screen ON")
                        onScreenOn()
                    }
                }
            }
        }
    }

}