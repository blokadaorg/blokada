package org.blokada.main

import android.content.Context
import com.github.salomonbrys.kodein.instance
import com.github.salomonbrys.kodein.with
import nl.komponents.kovenant.Kovenant
import nl.komponents.kovenant.Promise
import nl.komponents.kovenant.task
import org.blokada.property.Connection
import org.blokada.property.IWatchdog
import org.blokada.property.State
import gs.environment.Journal
import org.blokada.framework.KContext
import org.blokada.framework.di
import java.net.InetSocketAddress
import java.net.Socket

/**
 * AWatchdog is meant to test if device has Internet connectivity at this moment.
 *
 * It's used for getting connectivity state since Android's connectivity event cannot always be fully
 * trusted. It's also used to test if Blokada is working properly once activated (and periodically).
 */
class AWatchdog(
        private val ctx: Context
) : IWatchdog {

    private val s by lazy { ctx.di().instance<State>() }
    private val j by lazy { ctx.di().instance<Journal>() }
    private val kctx by lazy { ctx.di().with("watchdog").instance<KContext>() }

    override fun test(): Boolean {
        if (!s.watchdogOn()) return true
        val socket = Socket()
        socket.soTimeout = 3000
        return try { socket.connect(InetSocketAddress("google.com", 80), 3000); true }
        catch (e: Exception) { false } finally {
            try { socket.close() } catch (e: Exception) {}
        }
    }

    private val MAX = 120
    private var started = false
    private var wait = 1
    private var nextTask: Promise<*, *>? = null

    @Synchronized override fun start() {
        if (started) return
        if (!s.watchdogOn()) { return }
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
                val c = s.connection()
                if (c.connected != connected) {
                    // Connection state change will cause reactivating (and restarting watchdog)
                    j.log("watchdog change: connected: $connected")
                    s.connection %= Connection(
                            connected = connected,
                            tethering = c.tethering,
                            dnsServers = c.dnsServers
                    )
                    stop()
                } else {
                    Thread.sleep(Math.min(next, MAX) * 1000L)
                    nextTask = tick()
                }
            }
        }
    }
}
