package core

import android.app.job.JobInfo
import android.app.job.JobScheduler
import android.content.*
import android.net.ConnectivityManager
import android.net.wifi.WifiManager
import com.github.salomonbrys.kodein.instance
import com.github.salomonbrys.kodein.with
import gs.environment.Journal
import gs.environment.inject
import gs.property.I18n
import nl.komponents.kovenant.task


/**
 * ABootReceiver gets a ping from the OS after boot. Don't forget to register
 * in AndroidManifest with proper intent filter.
 */
class ABootReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent?) {
        scheduleJob(ctx)
    }

    fun scheduleJob(ctx: Context) {
        val serviceComponent = ComponentName(ctx, BootJobService::class.java)
        val builder = JobInfo.Builder(0, serviceComponent)
        builder.setOverrideDeadline(3 * 1000L)
        val jobScheduler = ctx.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler
        jobScheduler.schedule(builder.build())
    }
}

/**
 * AConnectivityReceiver monitors connectivity state changes and propagates them
 * to observable.
 *
 * Should be hooked up to:
 * - android.net.conn.CONNECTIVITY_CHANGE
 */
class AConnectivityReceiver : BroadcastReceiver() {

    override fun onReceive(ctx: Context, intent: Intent?) {
        task(ctx.inject().with("AConnectivityReceiver").instance()) {
            // Do it async so that Android can refresh the current network info before we access it
            val j: Journal = ctx.inject().instance()
            j.log("connectivity change")
            val s: State = ctx.inject().instance()
            s.connection.refresh()
        }
    }

    companion object {
        fun register(ctx: Context) {
            val filter = IntentFilter()
            filter.addAction(ConnectivityManager.CONNECTIVITY_ACTION)
            filter.addAction(WifiManager.WIFI_STATE_CHANGED_ACTION)
            filter.addAction(WifiManager.NETWORK_STATE_CHANGED_ACTION)
            ctx.registerReceiver(ctx.inject().instance<AConnectivityReceiver>(), filter)
        }

    }

}

class AScreenOnReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent?) {
        task(ctx.inject().with("AScreenOnReceiver").instance()) {
            // This causes everything to load
            val j: Journal = ctx.inject().instance()
            j.log("screen change")
            val s: State = ctx.inject().instance()
            s.screenOn.refresh()
        }
    }

    companion object {
        fun register(ctx: Context) {
            // Register AScreenOnReceiver
            val filter = IntentFilter()
            filter.addAction(Intent.ACTION_SCREEN_ON)
            filter.addAction(Intent.ACTION_SCREEN_OFF)
            ctx.registerReceiver(ctx.inject().instance<AScreenOnReceiver>(), filter)
        }

    }
}

class ALocaleReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent?) {
        task(ctx.inject().with("ALocaleReceiver").instance()) {
            val j: Journal = ctx.inject().instance()
            j.log("locale change")
            val i18n: I18n = ctx.inject().instance()
            i18n.locale.refresh(force = true)
        }
    }

    companion object {
        fun register(ctx: Context) {
            val filter = IntentFilter()
            filter.addAction(Intent.ACTION_LOCALE_CHANGED)
            ctx.registerReceiver(ctx.inject().instance<ALocaleReceiver>(), filter)
        }

    }
}
