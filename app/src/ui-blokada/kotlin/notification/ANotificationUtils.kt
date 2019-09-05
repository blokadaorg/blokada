package notification

import android.annotation.TargetApi
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.widget.Toast
import androidx.core.app.NotificationCompat
import com.github.salomonbrys.kodein.instance
import core.*
import gs.environment.inject
import gs.property.I18n
import org.blokada.R


/**
 * Will display / update a system notification for blocked packet.
 */
var requestCode = 0
fun displayNotification(ctx: Context, reason: String) {
    val b = NotificationCompat.Builder(ctx)
    b.setContentTitle(ctx.getString(R.string.notification_blocked_title))
    b.setContentText(ctx.getString(R.string.notification_blocked_text, reason))
    b.setSmallIcon(R.drawable.ic_stat_blokada)
    b.priority = NotificationCompat.PRIORITY_MAX
    b.setVibrate(LongArray(0))

    val intentActivity = Intent(ctx, PanelActivity::class.java)
    intentActivity.putExtra("notification", true)
    val piActivity = PendingIntent.getActivity(ctx, 0, intentActivity, 0)
    b.setContentIntent(piActivity)

    val iw = Intent(ctx, ANotificationsWhitelistService::class.java)
    iw.putExtra("host", reason)
    val piw = PendingIntent.getService(ctx, ++requestCode, iw, 0)
    val actionWhitelist = NotificationCompat.Action(R.drawable.ic_verified,
            ctx.getString(R.string.notification_blocked_whitelist), piw)
    b.addAction(actionWhitelist)

    val intent = Intent(ctx, ANotificationsOffService::class.java)
    val pi = PendingIntent.getService(ctx, 0, intent, 0)
    val actionNotificationsOff = NotificationCompat.Action(R.drawable.ic_blocked,
            ctx.getString(R.string.notification_blocked_off), pi)
    b.addAction(actionNotificationsOff)

    if (Build.VERSION.SDK_INT >= 26) {
        createNotificationChannel(ctx)
        b.setChannelId(default_id)
    }

    val notif = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    notif.notify(1, b.build())
}

fun hideNotification(ctx: Context) {
    val notif = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    notif.cancel(1)
}

/**
 * Will display / update a system notification to prevent Android from killing this app.
 */
fun createNotificationKeepAlive(ctx: Context, count: Int, last: String): Notification {
    val b = NotificationCompat.Builder(ctx)
    if (Product.current(ctx) == Product.DNS) {
        val i18n = ctx.inject().instance<I18n>()
        val choice = ctx.inject().instance<Dns>().choices().first { it.active }
        val id = if (choice.id.startsWith("custom")) "custom" else choice.id
        val provider = i18n.localisedOrNull("dns_${id}_name") ?: id.capitalize()
        val servers = printServers(ctx.inject().instance<Dns>().dnsServers())

        b.setContentTitle(provider)
        b.setContentText(ctx.getString(R.string.dns_keepalive_content, servers))
    } else {
        val t: Tunnel = ctx.inject().instance()
        val domainList = NotificationCompat.InboxStyle()
        val duplicates =ArrayList<String>(0)
        t.tunnelRecentDropped().asReversed().forEach { s ->
            if(!duplicates.contains(s)){
                duplicates.add(s)
                domainList.addLine(s)
            }
        }

        val intent = Intent(ctx, ANotificationsToggleService::class.java).putExtra("new_state",!t.enabled())
        val statePendingIntent = PendingIntent.getService(ctx, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT)
        if(t.enabled()) {
            b.addAction(R.drawable.ic_stat_blokada, ctx.resources.getString(R.string.notification_keepalive_deactivate), statePendingIntent)
        }else{
            b.addAction(R.drawable.ic_stat_blokada, ctx.resources.getString(R.string.notification_keepalive_activate), statePendingIntent)
        }

        b.setContentTitle(ctx.resources.getString(R.string.notification_keepalive_title, count))
        b.setContentText(ctx.getString(R.string.notification_keepalive_content, last))
        b.setStyle(domainList)
    }
    b.setSmallIcon(R.drawable.ic_stat_blokada)
    b.priority = NotificationCompat.PRIORITY_MIN
    b.setOngoing(true)

    val intentActivity = Intent(ctx, PanelActivity::class.java)
    intentActivity.putExtra("notification", true)
    val piActivity = PendingIntent.getActivity(ctx, 0, intentActivity, 0)
    b.setContentIntent(piActivity)

    if (Build.VERSION.SDK_INT >= 26) {
        createNotificationChannel(ctx)
        b.setChannelId(default_id)
    }

    return b.build()
}

val default_id = "blokada"
@TargetApi(26)
fun createNotificationChannel(ctx: Context, id: String = default_id, name: String = ctx.getString(R.string.branding_app_name) ) {
    val mNotificationManager = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    val importance = NotificationManager.IMPORTANCE_LOW
    val mChannel = NotificationChannel(id, name, importance)
    mNotificationManager.createNotificationChannel(mChannel)
}

fun hideNotificationKeepAlive(ctx: Context) {
    val notif = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    notif.cancel(3)
}

fun displayNotificationForUpdate(ctx: Context, versionName: String) {
    val b = NotificationCompat.Builder(ctx)
    b.setContentTitle(ctx.getString(R.string.update_notification_title))
    b.setContentText(ctx.getString(R.string.update_notification_text, versionName))
    b.setSmallIcon(R.drawable.ic_stat_blokada)
    b.setPriority(NotificationCompat.PRIORITY_LOW)
    b.setVibrate(LongArray(0))

    val intentActivity = Intent(ctx, PanelActivity::class.java)
    intentActivity.putExtra("notification", true)
    val piActivity = PendingIntent.getActivity(ctx, 0, intentActivity, 0)
    b.setContentIntent(piActivity)

    if (Build.VERSION.SDK_INT >= 26) {
        createNotificationChannel(ctx, "blokada_update", ctx.getString(R.string.update_notification_channel))
        b.setChannelId("blokada_update")
    }

    val notif = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    notif.notify(2, b.build())
}


class DisplayToastRunnable(private val mContext: Context, private var mText: String) : Runnable {
    override fun run() {
        Toast.makeText(mContext, mText, Toast.LENGTH_SHORT).show()
    }
}

fun displayAccountExpiredNotification(ctx: Context) {
    val b = NotificationCompat.Builder(ctx)
    b.setContentTitle(ctx.getString(R.string.notification_expired_title))
    b.setContentText(ctx.getString(R.string.notification_expired_description))
    b.setSmallIcon(R.drawable.ic_stat_blokada)
    b.setPriority(NotificationCompat.PRIORITY_MAX)
    b.setVibrate(LongArray(0))

    val intentActivity = Intent(ctx, PanelActivity::class.java)
    val piActivity = PendingIntent.getActivity(ctx, 0, intentActivity, 0)
    b.setContentIntent(piActivity)

    if (Build.VERSION.SDK_INT >= 26) {
        createNotificationChannel(ctx)
        b.setChannelId(default_id)
    }

    val notif = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    notif.notify(3, b.build())
}

fun displayLeaseExpiredNotification(ctx: Context) {
    val b = NotificationCompat.Builder(ctx)
    b.setContentTitle(ctx.getString(R.string.notification_lease_expired_title))
    b.setContentText(ctx.getString(R.string.notification_lease_expired_description))
    b.setSmallIcon(R.drawable.ic_stat_blokada)
    b.setPriority(NotificationCompat.PRIORITY_MAX)
    b.setVibrate(LongArray(0))

    val intentActivity = Intent(ctx, PanelActivity::class.java)
    val piActivity = PendingIntent.getActivity(ctx, 0, intentActivity, 0)
    b.setContentIntent(piActivity)

    if (Build.VERSION.SDK_INT >= 26) {
        createNotificationChannel(ctx)
        b.setChannelId(default_id)
    }

    val notif = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    notif.notify(4, b.build())
}
