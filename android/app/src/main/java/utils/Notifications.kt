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

package utils

import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import model.BlokadaException
import org.blokada.R
import service.Localised
import ui.MainActivity
import ui.utils.getPendingIntentForActivity

private const val IMPORTANCE_NONE = 0
private const val IMPORTANCE_DEFAULT = 3
private const val IMPORTANCE_HIGH = 4

enum class NotificationChannels(val title: Localised, val importance: Int) {
    ACTIVITY("Activity", IMPORTANCE_NONE),
    ANNOUNCEMENT("Announcements", IMPORTANCE_HIGH),
    UPDATE("Updates", IMPORTANCE_HIGH),
    BLOCKA("Blokada Plus", IMPORTANCE_HIGH);
}

sealed class NotificationPrototype(
    val id: Int,
    val channel: NotificationChannels,
    val autoCancel: Boolean = false,
    val create: (ctx: Context) -> NotificationCompat.Builder
)

class ExpiredNotification: NotificationPrototype(4, NotificationChannels.BLOCKA,
    create = { ctx ->
        val b = NotificationCompat.Builder(ctx)
        b.setContentTitle(ctx.getString(R.string.notification_acc_header))
        b.setContentText(ctx.getString(R.string.notification_acc_subtitle))
        b.setStyle(NotificationCompat.BigTextStyle().bigText(ctx.getString(R.string.notification_acc_body)))
        //b.setSmallIcon(R.drawable.ic_stat_blokada)
        b.setSmallIcon(R.drawable.ic_stat_blokada)
        b.setPriority(NotificationCompat.PRIORITY_MAX)
        b.setVibrate(LongArray(0))

        val intentActivity = Intent(ctx, MainActivity::class.java)
        val piActivity = ctx.getPendingIntentForActivity(intentActivity, 0)
        b.setContentIntent(piActivity)
    }
)

class ExpiredFamilyNotification: NotificationPrototype(5, NotificationChannels.BLOCKA,
    create = { ctx ->
        val b = NotificationCompat.Builder(ctx)
        b.setContentTitle(ctx.getString(R.string.notification_acc_header))
        b.setContentText(ctx.getString(R.string.family_notification_subtitle))
        b.setStyle(NotificationCompat.BigTextStyle().bigText(ctx.getString(R.string.notification_acc_body)))
        //b.setSmallIcon(R.drawable.ic_stat_blokada)
        b.setSmallIcon(R.drawable.ic_stat_blokada)
        b.setPriority(NotificationCompat.PRIORITY_MAX)
        b.setVibrate(LongArray(0))

        val intentActivity = Intent(ctx, MainActivity::class.java)
        val piActivity = ctx.getPendingIntentForActivity(intentActivity, 0)
        b.setContentIntent(piActivity)
    }
)

class OnboardingNotification: NotificationPrototype(6, NotificationChannels.BLOCKA,
    create = { ctx ->
        val b = NotificationCompat.Builder(ctx)
        b.setContentTitle(ctx.getString(R.string.activated_header))
        b.setContentText(ctx.getString(R.string.dnsprofile_desc_android))
        b.setSmallIcon(R.drawable.ic_stat_blokada)
        b.setPriority(NotificationCompat.PRIORITY_MAX)
        b.setVibrate(LongArray(0))

        val intentActivity = Intent(ctx, MainActivity::class.java)
        val piActivity = ctx.getPendingIntentForActivity(intentActivity, 0)
        b.setContentIntent(piActivity)
    }
)

class FamilyOnboardingNotification: NotificationPrototype(7, NotificationChannels.BLOCKA,
    create = { ctx ->
        val b = NotificationCompat.Builder(ctx)
        b.setContentTitle(ctx.getString(R.string.activated_header))
        b.setContentText(ctx.getString(R.string.dnsprofile_desc_android))
        b.setSmallIcon(R.drawable.ic_stat_blokada)
        b.setPriority(NotificationCompat.PRIORITY_MAX)
        b.setVibrate(LongArray(0))

        val intentActivity = Intent(ctx, MainActivity::class.java)
        val piActivity = ctx.getPendingIntentForActivity(intentActivity, 0)
        b.setContentIntent(piActivity)
    }
)

class NewMessageNotification(val body: String?): NotificationPrototype(8, NotificationChannels.BLOCKA,
    create = { ctx ->
        val b = NotificationCompat.Builder(ctx)
        b.setContentTitle(ctx.getString(R.string.notification_new_message_title))

        var c = "Tap to see the reply"
        if (!body.isNullOrEmpty()) {
            c = if (body.length > 32) body.substring(0, 32) + "..." else body
        }

        b.setContentText(c)
        b.setSmallIcon(R.drawable.ic_stat_blokada)
        b.setPriority(NotificationCompat.PRIORITY_MAX)
        b.setVibrate(LongArray(0))

        val intentActivity = Intent(ctx, MainActivity::class.java)
        val piActivity = ctx.getPendingIntentForActivity(intentActivity, 0)
        b.setContentIntent(piActivity)
    }
)

// The following are the notifications for v6.
// The old ones are left untouched to not change v5 behavior
// in case we want separate flavors.

class AccountExpiredNotification: NotificationPrototype(8, NotificationChannels.BLOCKA,
    create = { ctx ->
        val b = NotificationCompat.Builder(ctx)
        b.setContentTitle(ctx.getString(R.string.notification_acc_header))
        b.setContentText(ctx.getString(R.string.notification_acc_subtitle))
        b.setStyle(NotificationCompat.BigTextStyle().bigText(
            ctx.getString(R.string.notification_acc_body)
        ))
        b.setSmallIcon(R.drawable.ic_stat_blokada)
        b.setPriority(NotificationCompat.PRIORITY_MAX)
        b.setVibrate(LongArray(0))

        val intentActivity = Intent(ctx, MainActivity::class.java)
        val piActivity = ctx.getPendingIntentForActivity(intentActivity, 0)
        b.setContentIntent(piActivity)
    }
)

// When Plus lease expires. This should normally not happen as leases are
// automatically extended while the account is active.
class PlusLeaseExpiredNotification: NotificationPrototype(9, NotificationChannels.BLOCKA,
    create = { ctx ->
        val b = NotificationCompat.Builder(ctx)
        b.setContentTitle(ctx.getString(R.string.notification_lease_header))
        b.setContentText(ctx.getString(R.string.notification_vpn_expired_subtitle))
        b.setStyle(NotificationCompat.BigTextStyle().bigText(
            ctx.getString(R.string.notification_generic_body)
        ))
        b.setSmallIcon(R.drawable.ic_stat_blokada)
        b.setPriority(NotificationCompat.PRIORITY_MAX)
        b.setVibrate(LongArray(0))

        val intentActivity = Intent(ctx, MainActivity::class.java)
        val piActivity = ctx.getPendingIntentForActivity(intentActivity, 0)
        b.setContentIntent(piActivity)
    }
)

// When timed-pause runs out.
class PauseTimeoutNotification: NotificationPrototype(10, NotificationChannels.BLOCKA,
    create = { ctx ->
        val b = NotificationCompat.Builder(ctx)
        b.setContentTitle(ctx.getString(R.string.notification_pause_header))
        b.setContentText(ctx.getString(R.string.notification_pause_subtitle))
        b.setStyle(NotificationCompat.BigTextStyle().bigText(
            ctx.getString(R.string.notification_pause_body)
        ))
        b.setSmallIcon(R.drawable.ic_stat_blokada)
        b.setPriority(NotificationCompat.PRIORITY_MAX)
        b.setVibrate(LongArray(0))

        val intentActivity = Intent(ctx, MainActivity::class.java)
        val piActivity = ctx.getPendingIntentForActivity(intentActivity, 0)
        b.setContentIntent(piActivity)
    }
)

// When executing a command from the background (some silly android requirements)
class ExecutingCommandNotification: NotificationPrototype(11, NotificationChannels.ACTIVITY,
    create = { ctx ->
        val b = NotificationCompat.Builder(ctx)
        b.setContentTitle(ctx.getString(R.string.universal_status_processing))
        b.setSmallIcon(R.drawable.ic_stat_blokada)
        b.setPriority(NotificationCompat.PRIORITY_LOW)
        b.setVibrate(LongArray(0))
    }
)

fun notificationFromId(id: Int): NotificationPrototype {
    return when (id) {
        4 -> ExpiredNotification()
        5 -> AccountExpiredNotification()
        6 -> PlusLeaseExpiredNotification()
        7 -> PauseTimeoutNotification()
        else -> throw BlokadaException("unknown notification id")
    }
}