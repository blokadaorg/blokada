package org.blokada.main

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import com.github.salomonbrys.kodein.instance
import com.github.salomonbrys.kodein.with
import gs.environment.inject
import gs.property.I18n
import nl.komponents.kovenant.task
import org.blokada.property.State

/**
 * ABootReceiver gets a ping from the OS after boot. Don't forget to register
 * in AndroidManifest with proper intent filter.
 */
class ABootReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent?) {
        task(ctx.inject().with("ABootReceiver").instance()) {
            // This causes everything to load
            val s: State = ctx.inject().instance()
            s.connection.refresh()
        }
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
            val s: State = ctx.inject().instance()
            s.connection.refresh()
        }
    }

    companion object {
        fun register(ctx: Context) {
            val filter = IntentFilter()
            filter.addAction(ConnectivityManager.CONNECTIVITY_ACTION)
            ctx.registerReceiver(ctx.inject().instance<AConnectivityReceiver>(), filter)
        }

    }

}

class AScreenOnReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent?) {
        task(ctx.inject().with("AScreenOnReceiver").instance()) {
            // This causes everything to load
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
