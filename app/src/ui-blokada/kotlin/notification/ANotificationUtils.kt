package notification

import android.annotation.TargetApi
import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import com.github.salomonbrys.kodein.instance
import core.*
import core.bits.openInExternalBrowser
import gs.environment.inject
import gs.property.I18n
import kotlinx.coroutines.experimental.async
import kotlinx.coroutines.experimental.newSingleThreadContext
import org.blokada.R
import java.net.URL


//private val context = UI + logCoroutineExceptions()
private val context = newSingleThreadContext("notifications") + logCoroutineExceptions()

val notificationMain = BlokadaNotificationMain()

class BlokadaNotificationMain {

    private val manager = BlokadaNotificationManager()

    fun show(notification: BlokadaNotification) = async(context) {
        v("showing notification", notification)
        manager.show(notification)
    }

    fun cancel(notification: BlokadaNotification) = async(context) {
        v("cancelling notification", notification)
        manager.cancel(notification)
    }

    fun getNotification(notification: BlokadaNotification) = async(context) {
        v("getting notification", notification)
        manager.getNotification(notification)
    }
}

private class BlokadaNotificationManager {

    private val ctx: Context by lazy { getActiveContext()!! }
    private val i18n: I18n by lazy { ctx.ktx("").di().instance<I18n>() }
    private val notificationManager by lazy { ctx.getSystemService(Context.NOTIFICATION_SERVICE)
            as NotificationManager }

    private var channelsCreated: Boolean? = null

    fun show(notification: BlokadaNotification) {
        if (channelsCreated == null) createChannels()
        val builder = notification.create(ctx)
        if (channelsCreated == true) builder.setChannelId(notification.channel.name)
        val n = builder.build()
        if (notification.autoCancel) n.flags = Notification.FLAG_AUTO_CANCEL
        notificationManager.notify(notification.id, n)
    }

    fun cancel(notification: BlokadaNotification) {
        notificationManager.cancel(notification.id)
    }

    fun getNotification(notification: BlokadaNotification): Notification {
        if (channelsCreated == null) createChannels()
        val builder = notification.create(ctx)
        if (channelsCreated == true) builder.setChannelId(notification.channel.name)
        return builder.build()
    }

    private fun createChannels() {
        channelsCreated = if (Build.VERSION.SDK_INT >= 26) {
            v("creating notification channels")
            NotificationChannels.values().forEach {
                createNotificationChannel(it)
            }
            true
        } else false
    }

    @TargetApi(Build.VERSION_CODES.O)
    private fun createNotificationChannel(channel: NotificationChannels) {
        val mChannel = NotificationChannel(channel.name,
                i18n.getString(channel.nameResource), channel.importance)
        notificationManager.createNotificationChannel(mChannel)
    }
}

/**
 * Will display / update a system notification for blocked packet.
 */

private val IMPORTANCE_NONE = 0
private val IMPORTANCE_DEFAULT = 3
private val IMPORTANCE_HIGH = 4

enum class NotificationChannels(val nameResource: Resource, val importance: Int) {
    KEEP_ALIVE(R.string.notification_keepalive_text.res(), IMPORTANCE_NONE),
    FILTERED(R.string.notification_channel_filtered.res(), IMPORTANCE_NONE),
    ANNOUNCEMENT(R.string.notification_channel_announcements.res(), IMPORTANCE_HIGH),
    UPDATE(R.string.update_notification_channel.res(), IMPORTANCE_HIGH),
    BLOCKA_VPN(R.string.notification_channel_vpn.res(), IMPORTANCE_HIGH),
    COMMON(R.string.notification_channel_other.res(), IMPORTANCE_DEFAULT);
}

sealed class BlokadaNotification(val id: Int, val channel: NotificationChannels,
                                 val autoCancel: Boolean = false,
     val create: (ctx: Context) -> NotificationCompat.Builder)

private var requestCode = 0

class FilteredNotification(reason: String, counter: Int = 0): BlokadaNotification(1, NotificationChannels.FILTERED,
        create = { ctx ->
            val b = NotificationCompat.Builder(ctx)
            b.setContentTitle(ctx.resources.getString(R.string.notification_keepalive_title, counter))
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
        }
)

class KeepAliveNotification: BlokadaNotification(2, NotificationChannels.KEEP_ALIVE,
        create = { ctx ->
            val b = NotificationCompat.Builder(ctx)
            b.setContentTitle(ctx.getString(R.string.notification_keepalive_title_new))
            b.setContentText(ctx.getString(R.string.notification_keepalive_text_new))
            b.setSmallIcon(R.drawable.ic_stat_blokada)
            b.priority = NotificationCompat.PRIORITY_MIN

            val intentActivity = getIntentForNotificationChannelsSettings(ctx)
            val piActivity = PendingIntent.getActivity(ctx, 0, intentActivity, 0)
            b.setContentIntent(piActivity)
        }
)

class UsefulKeepAliveNotification(val count: Int, val last: String): BlokadaNotification(2,
        NotificationChannels.KEEP_ALIVE,
        create = { ctx ->
            val i18n = ctx.inject().instance<I18n>()
            val choice = ctx.inject().instance<Dns>().choices().first { it.active }
            val servers = printServers(ctx.inject().instance<Dns>().dnsServers())
            val t: Tunnel = ctx.inject().instance()

            val b = NotificationCompat.Builder(ctx)
            if (Product.current(ctx) == Product.GOOGLE) {
                val id = if (choice.id.startsWith("custom")) "custom" else choice.id
                val provider = i18n.localisedOrNull("dns_${id}_name") ?: id.capitalize()

                b.setContentTitle(provider)
                b.setContentText(ctx.getString(R.string.dns_keepalive_content, servers))
            } else {
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
        }
)

fun getIntentForNotificationChannelsSettings(ctx: Context) = Intent().apply {
    action = "android.settings.APP_NOTIFICATION_SETTINGS"
    putExtra("app_package", ctx.packageName)
    putExtra("app_uid", ctx.applicationInfo.uid)
    putExtra("android.provider.extra.APP_PACKAGE", ctx.packageName)
}

class UpdateNotification(versionName: String): BlokadaNotification(3, NotificationChannels.UPDATE,
        create = { ctx ->
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
        }
)

class AccountInactiveNotification: BlokadaNotification(4, NotificationChannels.BLOCKA_VPN,
        create = { ctx ->
            val b = NotificationCompat.Builder(ctx)
            b.setContentTitle(ctx.getString(R.string.notification_expired_title))
            b.setContentText(ctx.getString(R.string.notification_expired_description))
            b.setStyle(NotificationCompat.BigTextStyle().bigText(ctx.getString(R.string.notification_expired_description)))
            b.setSmallIcon(R.drawable.ic_stat_blokada)
            b.setPriority(NotificationCompat.PRIORITY_MAX)
            b.setVibrate(LongArray(0))

            val intentActivity = Intent(ctx, PanelActivity::class.java)
            val piActivity = PendingIntent.getActivity(ctx, 0, intentActivity, 0)
            b.setContentIntent(piActivity)
        }
)

class LeaseExpiredNotification: BlokadaNotification(5, NotificationChannels.BLOCKA_VPN,
        create = { ctx ->
            val b = NotificationCompat.Builder(ctx)
            b.setContentTitle(ctx.getString(R.string.notification_lease_expired_title))
            b.setContentText(ctx.getString(R.string.notification_lease_expired_description))
            b.setStyle(NotificationCompat.BigTextStyle().bigText(ctx.getString(R.string.notification_lease_expired_description)))
            b.setSmallIcon(R.drawable.ic_stat_blokada)
            b.priority = NotificationCompat.PRIORITY_MAX
            b.setVibrate(LongArray(0))

            val intentActivity = Intent(ctx, PanelActivity::class.java)
            val piActivity = PendingIntent.getActivity(ctx, 0, intentActivity, 0)
            b.setContentIntent(piActivity)
        }
)

class AnnouncementNotification(announcement: Announcement): BlokadaNotification(6,
        NotificationChannels.ANNOUNCEMENT, autoCancel = true,
        create = { ctx ->
            val b = NotificationCompat.Builder(ctx)
            b.setContentTitle(announcement.title)
            b.setContentText(announcement.tagline)
            b.setStyle(NotificationCompat.BigTextStyle().bigText(announcement.tagline))
            b.setSmallIcon(R.drawable.ic_stat_blokada)
            b.priority = NotificationCompat.PRIORITY_MAX
            b.setVibrate(LongArray(0))

            val intent = Intent(ctx, AnnouncementNotificationTappedService::class.java)
            val pi = PendingIntent.getService(ctx, 0, intent, 0)
            b.setContentIntent(pi)
        }
)

class AnnouncementNotificationTappedService : IntentService("announcementNotification") {

    override fun onHandleIntent(intent: Intent) {
        v("announcement notification tapped")
        markAnnouncementAsSeen()
        openInExternalBrowser(this, URL(getAnnouncementUrl()))
    }

}
