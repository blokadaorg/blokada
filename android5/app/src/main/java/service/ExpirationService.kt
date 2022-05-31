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

package service

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import model.ActiveUntil
import ui.beforeNow
import ui.utils.cause
import ui.utils.getPendingIntentForBroadcast
import utils.Logger
import utils.NotificationPrototype


object ExpirationService {

    private val log = Logger("Expiration")
    private val context = ContextService
    private val alarmManager by lazy {
        context.requireContext().getSystemService(Context.ALARM_SERVICE) as AlarmManager
    }

    var onExpired: () -> Any = {}

    fun setExpirationAlarm(n: NotificationPrototype, activeUntil: ActiveUntil) {
        log.v("Setting expiration alarm for: $n at: $activeUntil")

        val time = activeUntil.time
        log.v("Timestamp: ${time}, now: ${System.currentTimeMillis()}")

        if (activeUntil.beforeNow()) {
            log.w("Tried to set alarm for a date in the past, triggering immediately")
            onExpired()
            return
        }

        try {
            context.requireContext().let { ctx ->
                val operation = Intent(ctx, ExpirationReceiver::class.java).let { intent ->
                    ctx.getPendingIntentForBroadcast(intent, PendingIntent.FLAG_UPDATE_CURRENT)
                }
                alarmManager.set(AlarmManager.RTC, time, operation)
                log.v("Expiration alarm in AlarmManager set")
            }
        } catch (ex: Exception) {
            log.e("Could not set expiration alarm".cause(ex))
        }
    }

}

class ExpirationReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        Logger.v("Expiration", "Alarm expire received, now: ${System.currentTimeMillis()}")
        ExpirationService.onExpired()
    }
}