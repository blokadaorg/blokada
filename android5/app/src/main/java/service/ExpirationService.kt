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