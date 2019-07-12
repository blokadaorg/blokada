package gs.property

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.net.wifi.WifiManager
import android.os.PowerManager
import com.github.salomonbrys.kodein.*
import core.ktx
import gs.environment.*
import nl.komponents.kovenant.Kovenant
import nl.komponents.kovenant.Promise
import nl.komponents.kovenant.task
import java.net.InetSocketAddress
import java.net.Socket

abstract class Device {
    abstract val appInForeground: IProperty<Boolean>
    abstract val screenOn: IProperty<Boolean>
    abstract val connected: IProperty<Boolean>
    abstract val tethering: IProperty<Boolean>
    abstract val watchdogOn: IProperty<Boolean>
    abstract val onWifi: IProperty<Boolean>
    abstract val reports: IProperty<Boolean>

    fun isWaiting(): Boolean {
        return !connected()
    }

}

class DeviceImpl (
        kctx: Worker,
        xx: Environment,
        ctx: Context = xx().instance()
) : Device() {

    private val pm: PowerManager by xx.instance()
    private val watchdog: IWatchdog by xx.instance()

    override val appInForeground = newProperty(kctx, { false })
    override val screenOn = newProperty(kctx, { pm.isInteractive })
    override val connected = newProperty(kctx, zeroValue = { true }, refresh = {
        // With watchdog off always returning true, we basically disable detection.
        // Because isConnected sometimes returns false when we are actually online.
        val c = isConnected(ctx) or watchdog.test()
        "device".ktx().v("connected", c)
        c
    } )
    override val tethering = newProperty(kctx, { isTethering(ctx)} )

    override val watchdogOn = newPersistedProperty(kctx, BasicPersistence(xx, "watchdogOn"),
            { false })

    override val onWifi = newProperty(kctx, { isWifi(ctx) } )

    override val reports = newPersistedProperty(kctx, BasicPersistence(xx, "reports"),
            { true }
    )

}

class ConnectivityReceiver : BroadcastReceiver() {

    override fun onReceive(ctx: Context, intent: Intent?) {
        task(ctx.inject().with("ConnectivityReceiver").instance()) {
            // Do it async so that Android can refresh the current network info before we access it
            "device:connectivity".ktx().v("connectivity receiver ping")
            val s: Device = ctx.inject().instance()
            s.connected.refresh()
            s.onWifi.refresh()
        }
    }

    companion object {
        fun register(ctx: Context) {
            val filter = IntentFilter()
            filter.addAction(ConnectivityManager.CONNECTIVITY_ACTION)
            filter.addAction(WifiManager.WIFI_STATE_CHANGED_ACTION)
            filter.addAction(WifiManager.NETWORK_STATE_CHANGED_ACTION)
            ctx.registerReceiver(ctx.inject().instance<ConnectivityReceiver>(), filter)
        }

    }

}

fun newDeviceModule(ctx: Context): Kodein.Module {
    return Kodein.Module {
        bind<Device>() with singleton {
            DeviceImpl(kctx = with("gscore").instance(2), xx = lazy)
        }
        bind<ConnectivityReceiver>() with singleton { ConnectivityReceiver() }
        bind<ScreenOnReceiver>() with singleton { ScreenOnReceiver() }
        bind<LocaleReceiver>() with singleton { LocaleReceiver() }
        bind<IWatchdog>() with singleton { AWatchdog(ctx) }
        onReady {
            // Register various Android listeners to receive events
            task {
                // In a task because we are in DI and using DI can lead to stack overflow
                ConnectivityReceiver.register(ctx)
                ScreenOnReceiver.register(ctx)
                LocaleReceiver.register(ctx)
            }
        }
    }
}

class ScreenOnReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent?) {
        task(ctx.inject().with("ScreenOnReceiver").instance()) {
            // This causes everything to load
            "device:screenOn".ktx().v("screen receiver ping")
            val s: Device = ctx.inject().instance()
            s.screenOn.refresh()
        }
    }

    companion object {
        fun register(ctx: Context) {
            // Register ScreenOnReceiver
            val filter = IntentFilter()
            filter.addAction(Intent.ACTION_SCREEN_ON)
            filter.addAction(Intent.ACTION_SCREEN_OFF)
            ctx.registerReceiver(ctx.inject().instance<ScreenOnReceiver>(), filter)
        }

    }
}

class LocaleReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent?) {
        task(ctx.inject().with("LocaleReceiver").instance()) {
            "device:locale".ktx().v("locale receiver ping")
            val i18n: I18n = ctx.inject().instance()
            i18n.locale.refresh(force = true)
        }
    }

    companion object {
        fun register(ctx: Context) {
            val filter = IntentFilter()
            filter.addAction(Intent.ACTION_LOCALE_CHANGED)
            ctx.registerReceiver(ctx.inject().instance<LocaleReceiver>(), filter)
        }

    }
}

interface IWatchdog {
    fun start()
    fun stop()
    fun test(): Boolean
}

/**
 * AWatchdog is meant to test if device has Internet connectivity at this moment.
 *
 * It's used for getting connectivity state since Android's connectivity event cannot always be fully
 * trusted. It's also used to test if Blokada is working properly once activated (and periodically).
 */
class AWatchdog(
        private val ctx: Context
) : IWatchdog {

    private val d by lazy { ctx.inject().instance<Device>() }
    private val kctx by lazy { ctx.inject().with("watchdog").instance<Worker>() }
    private val ktx by lazy { "device:watchdog".ktx() }

    override fun test(): Boolean {
        if (!d.watchdogOn()) return true
        ktx.v("watchdog ping")
        val socket = Socket()
        socket.soTimeout = 3000
        return try {
            socket.connect(InetSocketAddress("cloudflare.com", 80), 3000);
            ktx.v("watchdog ping ok")
            true
        }
        catch (e: Exception) {
            ktx.v("watchdog ping fail")
            false
        } finally {
            try { socket.close() } catch (e: Exception) {}
        }
    }

    private val MAX = 120
    private var started = false
    private var wait = 1
    private var nextTask: Promise<*, *>? = null

    @Synchronized override fun start() {
        if (started) return
        if (!d.watchdogOn()) { return }
        started = true
        wait = 1
        if (nextTask != null) Kovenant.cancel(nextTask!!, Exception("cancelled"))
        nextTask = tick()
    }

    @Synchronized override fun stop() {
        started = false
        if (nextTask != null) Kovenant.cancel(nextTask!!, Exception("cancelled"))
        nextTask = null
    }

    private fun tick(): Promise<*, *> {
        return task(kctx) {
            if (started) {
                // Delay the first check to not cause false positives
                if (wait == 1) Thread.sleep(1000L)
                val connected = test()
                val next = if (connected) wait * 2 else wait
                wait *= 2
                if (d.connected() != connected) {
                    // Connection state change will cause reactivating (and restarting watchdog)
                    ktx.v("watchdog change: connected: $connected")
                    d.connected %= connected
                    stop()
                } else {
                    Thread.sleep(Math.min(next, MAX) * 1000L)
                    nextTask = tick()
                }
            }
        }
    }
}
