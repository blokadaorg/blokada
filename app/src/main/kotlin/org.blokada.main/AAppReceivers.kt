package org.blokada.main

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import com.github.salomonbrys.kodein.instance
import com.github.salomonbrys.kodein.with
import nl.komponents.kovenant.task
import org.blokada.framework.di
import org.blokada.property.State

/**
 * ABootReceiver gets a ping from the OS after boot. Don't forget to register
 * in AndroidManifest with proper intent filter.
 */
class ABootReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent?) {
        task(ctx.di().with("ABootReceiver").instance()) {
            // This causes everything to load
            val s: State = ctx.di().instance()
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
        task(ctx.di().with("AConnectivityReceiver").instance()) {
            // Do it async so that Android can refresh the current network info before we access it
            val s: State = ctx.di().instance()
            s.connection.refresh()
        }
    }

    companion object {
        fun register(ctx: Context) {
            val filter = IntentFilter()
            filter.addAction(ConnectivityManager.CONNECTIVITY_ACTION)
            ctx.registerReceiver(ctx.di().instance<AConnectivityReceiver>(), filter)
        }

        fun unregister(ctx: Context) {
            ctx.unregisterReceiver(ctx.di().instance<AConnectivityReceiver>())
        }
    }

}

class AScreenOnReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent?) {
        task(ctx.di().with("AScreenOnReceiver").instance()) {
            // This causes everything to load
            val s: State = ctx.di().instance()
            s.screenOn.refresh()
        }
    }

    companion object {
        fun register(ctx: Context) {
            // Register AScreenOnReceiver
            val filter = IntentFilter()
            filter.addAction(Intent.ACTION_SCREEN_ON)
            filter.addAction(Intent.ACTION_SCREEN_OFF)
            ctx.registerReceiver(ctx.di().instance<AScreenOnReceiver>(), filter)
        }

        fun unregister(ctx: Context) {
            ctx.unregisterReceiver(ctx.di().instance<AScreenOnReceiver>())
        }
    }
}

class ALocaleReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent?) {
        task(ctx.di().with("ALocaleReceiver").instance()) {
            val s: State = ctx.di().instance()
            s.localised.refresh(force = true)
        }
    }

    companion object {
        fun register(ctx: Context) {
            val filter = IntentFilter()
            filter.addAction(Intent.ACTION_LOCALE_CHANGED)
            ctx.registerReceiver(ctx.di().instance<ALocaleReceiver>(), filter)
        }

        fun unregister(ctx: Context) {
            ctx.unregisterReceiver(ctx.di().instance<ALocaleReceiver>())
        }
    }
}
