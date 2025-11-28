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
import android.util.Log
import org.blokada.R
import utils.ExpiredFamilyNotification
import utils.ExpiredNotification
import utils.FamilyOnboardingNotification
import utils.NewMessageNotification
import utils.NotificationChannels
import utils.NotificationPrototype
import utils.OnboardingNotification
import utils.QuickSettingsNotification
import utils.WeeklyReportNotification
import java.util.Calendar
import java.util.Date
import org.json.JSONObject

// TODO: make a channel level enum
val NOTIF_ACC_EXP = "accountExpired"
val NOTIF_ACC_EXP_FAM = "accountExpiredFamily"
val NOTIF_LEASE_EXP = "plusLeaseExpired"
val NOTIF_PAUSE = "pauseTimeout"
val NOTIF_ONBOARDING = "onboardingDnsAdvice"
val NOTIF_ONBOARDING_FAMILY = "onboardingDnsAdviceFamily"
val NOTIF_NEW_MESSAGE = "supportNewMessage"
val NOTIF_QUICKSETTINGS = "quickSettings" // Shown while QS is changing app status
val NOTIF_WEEKLY_REPORT = "weeklyReport"

private const val WEEKLY_REPORT_BACKGROUND_LEAD_MS = 60 * 60 * 1000L

object NotificationService {
    private val context by lazy { ContextService }
    private val notificationManager by lazy {
        context.requireContext()
            .getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
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

    fun show(notificationId: String, atWhen: Date, body: String? = null, scheduleBackground: Boolean = true) {
        if (EnvironmentService.getFlavor() == "family" && notificationId == NOTIF_WEEKLY_REPORT) {
            Log.d("NotificationService", "Skipping weekly report scheduling on family flavor")
            return
        }
        val ctx = context.requireAppContext()
        val intent = Intent(ctx, NotificationAlarmReceiver::class.java)
        intent.putExtra("id", notificationId)
        if (body != null) intent.putExtra("body", body)
        val parsedPayload = WeeklyReportPayload.fromJson(ctx, body)
        val pendingIntent = PendingIntent.getBroadcast(
            ctx,
            notificationId.hashCode(),
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val calendar = Calendar.getInstance()
        calendar.time = atWhen

        alarmManager.set(AlarmManager.RTC_WAKEUP, calendar.timeInMillis, pendingIntent)
        Log.d("NotificationService", "Scheduled $notificationId at ${calendar.time}")

        if (notificationId == NOTIF_WEEKLY_REPORT && scheduleBackground) {
            scheduleWeeklyReportBackground(ctx, calendar.timeInMillis, parsedPayload)
        }
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

    private fun scheduleWeeklyReportBackground(
        ctx: Context,
        targetAt: Long,
        payload: WeeklyReportPayload?
    ) {
        val refreshedContent = (payload ?: WeeklyReportPayload.defaults(ctx)).refreshed(ctx)
        val leadMs = payload?.backgroundLeadMs ?: WEEKLY_REPORT_BACKGROUND_LEAD_MS
        val backgroundAt = targetAt - leadMs
        if (backgroundAt <= System.currentTimeMillis()) {
            Log.d("NotificationService", "Skipping weekly report background schedule, backgroundAt is past")
            return
        }

        val intent = Intent(ctx, WeeklyReportBackgroundReceiver::class.java)
        intent.putExtra("id", NOTIF_WEEKLY_REPORT)
        intent.putExtra("targetAt", targetAt)
        intent.putExtra("title", refreshedContent.title)
        intent.putExtra("body", refreshedContent.body)

        val pendingIntent = PendingIntent.getBroadcast(
            ctx,
            NOTIF_WEEKLY_REPORT.hashCode() + 1,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        alarmManager.set(AlarmManager.RTC_WAKEUP, backgroundAt, pendingIntent)
        Log.d("NotificationService", "Scheduled weekly report background at ${Date(backgroundAt)}")
    }
}

class NotificationAlarmReceiver : BroadcastReceiver() {
    private val notification by lazy { NotificationService }

    override fun onReceive(context: Context, intent: Intent) {
        val n = when (intent.getStringExtra("id")) {
            NOTIF_ACC_EXP -> ExpiredNotification()
            NOTIF_ACC_EXP_FAM -> ExpiredFamilyNotification()
            NOTIF_ONBOARDING -> OnboardingNotification()
            NOTIF_ONBOARDING_FAMILY -> FamilyOnboardingNotification()
            NOTIF_NEW_MESSAGE -> NewMessageNotification(intent.getStringExtra("body"))
            NOTIF_QUICKSETTINGS -> QuickSettingsNotification()
            NOTIF_WEEKLY_REPORT -> {
                val payload = WeeklyReportPayload.fromJson(context, intent.getStringExtra("body"))
                val content = payload ?: WeeklyReportPayload.defaults(context)
                WeeklyReportNotification(content.title, content.body)
            }
            else -> null
        }

        if (n != null) notification.show(n)
    }
}

class WeeklyReportBackgroundReceiver : BroadcastReceiver() {
    private val notification by lazy { NotificationService }

    override fun onReceive(context: Context, intent: Intent) {
        val targetAt = intent.getLongExtra("targetAt", -1L)
        if (targetAt <= 0L) return

        val refreshedTitle = intent.getStringExtra("title")
        val refreshedBody = intent.getStringExtra("body")

        Log.d("NotificationService", "Weekly report background execution at ${Date()} for target ${Date(targetAt)}")
        // TODO: refresh stats here once available
        notification.show(
            NOTIF_WEEKLY_REPORT,
            Date(targetAt),
            WeeklyReportPayload(
                refreshedTitle,
                refreshedBody,
                refreshedTitle,
                refreshedBody,
                WEEKLY_REPORT_BACKGROUND_LEAD_MS
            ).toJson(),
            scheduleBackground = false
        )
    }
}

data class WeeklyReportPayload(
    val title: String?,
    val body: String?,
    val refreshedTitle: String?,
    val refreshedBody: String?,
    val backgroundLeadMs: Long
) {
    fun toJson(): String {
        val json = JSONObject()
        if (title != null) json.put("title", title)
        if (body != null) json.put("body", body)
        if (refreshedTitle != null) json.put("refreshedTitle", refreshedTitle)
        if (refreshedBody != null) json.put("refreshedBody", refreshedBody)
        json.put("backgroundLeadMs", backgroundLeadMs)
        return json.toString()
    }

    fun refreshed(ctx: Context): WeeklyReportPayload {
        val titleValue = refreshedTitle ?: ctx.getString(R.string.notification_weekly_report_refresh_title)
        val bodyValue = refreshedBody ?: ctx.getString(R.string.notification_weekly_report_refresh_body)
        return WeeklyReportPayload(
            title = titleValue,
            body = bodyValue,
            refreshedTitle = refreshedTitle,
            refreshedBody = refreshedBody,
            backgroundLeadMs = backgroundLeadMs
        )
    }

    companion object {
        fun fromJson(ctx: Context, body: String?): WeeklyReportPayload? {
            if (body == null) return null
            return try {
                val json = JSONObject(body)
                WeeklyReportPayload(
                    title = json.optString("title", null),
                    body = json.optString("body", null),
                    refreshedTitle = json.optString("refreshedTitle", null),
                    refreshedBody = json.optString("refreshedBody", null)
                        .ifEmpty { ctx.getString(R.string.notification_weekly_report_refresh_body) + " (bg)" },
                    backgroundLeadMs = json.optLong("backgroundLeadMs", WEEKLY_REPORT_BACKGROUND_LEAD_MS)
                )
            } catch (e: Exception) {
                Log.e("NotificationService", "Failed to parse weekly report payload: ${e.message}")
                defaults(ctx)
            }
        }

        fun defaults(ctx: Context): WeeklyReportPayload {
            return WeeklyReportPayload(
                ctx.getString(R.string.notification_weekly_report_title),
                ctx.getString(R.string.notification_weekly_report_body),
                ctx.getString(R.string.notification_weekly_report_refresh_title),
                ctx.getString(R.string.notification_weekly_report_refresh_body) + " (bg)",
                WEEKLY_REPORT_BACKGROUND_LEAD_MS
            )
        }
    }
}
