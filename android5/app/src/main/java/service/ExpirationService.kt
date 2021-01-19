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
import utils.ExpiredNotification
import utils.Logger
import java.util.Date


object ExpirationService {

    private val log = Logger("Expiration")
    private val context = ContextService
    private val alarmManager by lazy {
        context.requireContext().getSystemService(Context.ALARM_SERVICE) as AlarmManager
    }

    var onExpired = {}

    fun setExpirationAlarm(activeUntil: ActiveUntil) {
        log.v("Setting expiration alarm at: $activeUntil")

        if (activeUntil.beforeNow()) {
            log.w("Tried to set alarm for a date in the past, triggering immediately")
            onExpired()
            return
        }

        try {
            context.requireContext().let { ctx ->
                val operation = Intent(ctx, ExpirationReceiver::class.java).let { intent ->
                    PendingIntent.getBroadcast(ctx, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT)
                }
                alarmManager.set(AlarmManager.RTC, activeUntil.time, operation)
                log.v("Expiration alarm set")
            }
        } catch (ex: Exception) {
            log.e("Could not set expiration alarm".cause(ex))
        }
    }

}

class ExpirationReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, p1: Intent) {
        Logger.v("Expiration", "Alarm received")
        NotificationService.show(ExpiredNotification())
        ExpirationService.onExpired()
    }
}