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

import android.annotation.TargetApi
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import utils.Logger
import utils.NotificationChannels
import utils.NotificationPrototype

object NotificationService {

    private val log = Logger("Notification")
    private val context = ContextService
    private val notificationManager by lazy {
        context.requireContext().getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    }

    private var useChannels: Boolean = false

    init {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            log.v("Creating notification channels")
            NotificationChannels.values().forEach {
                createNotificationChannel(it)
            }
            useChannels = true
        }
    }

    fun show(notification: NotificationPrototype) {
        val builder = notification.create(context.requireContext())
        if (useChannels) builder.setChannelId(notification.channel.name)
        val n = builder.build()
        if (notification.autoCancel) n.flags = Notification.FLAG_AUTO_CANCEL
        notificationManager.notify(notification.id, n)
    }

    fun build(notification: NotificationPrototype): Notification {
        val builder = notification.create(context.requireContext())
        if (useChannels) builder.setChannelId(notification.channel.name)
        val n = builder.build()
        if (notification.autoCancel) n.flags = Notification.FLAG_AUTO_CANCEL
        return n
    }

    fun cancel(notification: NotificationPrototype) {
        notificationManager.cancel(notification.id)
    }

    @TargetApi(Build.VERSION_CODES.O)
    private fun createNotificationChannel(channel: NotificationChannels) {
        val mChannel = NotificationChannel(
            channel.name,
            channel.title,
            channel.importance
        )
        notificationManager.createNotificationChannel(mChannel)
    }

}