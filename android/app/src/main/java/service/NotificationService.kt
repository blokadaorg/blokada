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
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import utils.ExpiredFamilyNotification
import utils.ExpiredNotification
import utils.NotificationChannels
import utils.NotificationPrototype
import utils.OnboardingNotification
import java.util.Calendar
import java.util.Date

// TODO: make a channel level enum
val NOTIF_ACC_EXP = "accountExpired"
val NOTIF_ACC_EXP_FAM = "accountExpiredFamily"
val NOTIF_LEASE_EXP = "plusLeaseExpired"
val NOTIF_PAUSE = "pauseTimeout"
val NOTIF_ONBOARDING = "onboardingDnsAdvice"

object NotificationService {
    private val context by lazy { ContextService }
    private val notificationManager by lazy {
        context.requireContext().getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    }
    private val alarmManager by lazy {
        context.requireContext().getSystemService(Context.ALARM_SERVICE) as AlarmManager
    }

    private var useChannels: Boolean = false

    init {
        NotificationChannels.values().forEach {
            createNotificationChannel(it)
        }
        useChannels = true
    }

    fun show(notificationId: String, atWhen: Date) {
        val ctx = context.requireAppContext()
        val intent = Intent(ctx, NotificationAlarmReceiver::class.java)
        intent.putExtra("id", notificationId)
        val pendingIntent = PendingIntent.getBroadcast(
            ctx, 0, intent, PendingIntent.FLAG_IMMUTABLE
        )

        val calendar = Calendar.getInstance()
        calendar.time = atWhen

        alarmManager.set(AlarmManager.RTC_WAKEUP, calendar.timeInMillis, pendingIntent)
    }

    fun dismissAll() {
        notificationManager.cancelAll()
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

    private fun createNotificationChannel(channel: NotificationChannels) {
        val mChannel = NotificationChannel(
            channel.name,
            channel.title,
            channel.importance
        )
        notificationManager.createNotificationChannel(mChannel)
    }

    fun hasPermissions(): Boolean {
        return notificationManager.areNotificationsEnabled()
    }
}

class NotificationAlarmReceiver : BroadcastReceiver() {
    private val notification by lazy { NotificationService }

    override fun onReceive(context: Context, intent: Intent) {
        val n = when (intent.getStringExtra("id")) {
            NOTIF_ACC_EXP -> ExpiredNotification()
            NOTIF_ACC_EXP_FAM -> ExpiredFamilyNotification()
            NOTIF_ONBOARDING -> OnboardingNotification()
            else -> null
        }

        if (n != null) notification.show(n)
    }
}