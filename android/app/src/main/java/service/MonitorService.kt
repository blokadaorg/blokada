/*
 * This file is part of Blokada.
 *
 * Blokada is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Blokada is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Blokada.  If not, see <https://www.gnu.org/licenses/>.
 *
 * Copyright © 2020 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package service

import android.app.Service
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.Binder
import android.os.IBinder
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import model.BlokadaException
import model.Stats
import model.TunnelStatus
import engine.*
import ui.utils.cause
import utils.Logger
import utils.MonitorNotification

object MonitorService {

    private var strategy: MonitorServiceStrategy = SimpleMonitorServiceStrategy()

    fun setup(useForeground: Boolean) {
        if (useForeground) {
            strategy = ForegroundMonitorServiceStrategy()
        }

        strategy.setup()
    }

    fun setCounter(counter: Long) = strategy.setCounter(counter)
    fun setStats(stats: Stats) = strategy.setStats(stats)
    fun setTunnelStatus(tunnelStatus: TunnelStatus) = strategy.setTunnelStatus(tunnelStatus)

}

private interface MonitorServiceStrategy {
    fun setup()
    fun setCounter(counter: Long)
    fun setStats(stats: Stats)
    fun setTunnelStatus(tunnelStatus: TunnelStatus)
}

// This strategy just shows the notification
private class SimpleMonitorServiceStrategy: MonitorServiceStrategy {

    private val notification = NotificationService

    private var counter: Long = 0
    private var lastDenied: List<Host> = emptyList()
    private var tunnelStatus: TunnelStatus = TunnelStatus.off()

    override fun setup() {}

    override fun setCounter(counter: Long) {
        this.counter = counter
        updateNotification()
    }

    override fun setStats(stats: Stats) {
        lastDenied = stats.entries.sortedByDescending { it.time }.take(5).map { it.name }
        updateNotification()
    }

    override fun setTunnelStatus(tunnelStatus: TunnelStatus) {
        this.tunnelStatus = tunnelStatus
        updateNotification()
    }

    private fun updateNotification() {
        val prototype = MonitorNotification(tunnelStatus, counter, lastDenied)
        notification.show(prototype)
    }

}

// This strategy keeps the app alive while showing the notification
private class ForegroundMonitorServiceStrategy: MonitorServiceStrategy {

    private val log = Logger("Monitor")
    private val context = ContextService
    private val scope = GlobalScope

    private var connection: ForegroundConnection? = null
        @Synchronized get
        @Synchronized set

    override fun setup() {
        try {
            log.v("Starting Foreground Service")
            val ctx = context.requireAppContext()
            ctx.startService(Intent(ctx, ForegroundService::class.java))
        } catch (ex: Exception) {
            log.w("Could not start ForegroundService".cause(ex))
        }

        scope.launch {
            // To initially bind to the ForegroundService
            getConnection()
        }
    }

    override fun setCounter(counter: Long) {
        scope.launch {
            getConnection().binder.onNewStats(counter, null, null)
        }
    }

    override fun setStats(stats: Stats) {
        scope.launch {
            val lastDenied = stats.entries.sortedByDescending { it.time }.take(5).map { it.name }
            getConnection().binder.onNewStats(null, lastDenied, null)
        }
    }

    override fun setTunnelStatus(tunnelStatus: TunnelStatus) {
        scope.launch {
            getConnection().binder.onNewStats(null, null, tunnelStatus)
        }
    }

    private suspend fun getConnection(): ForegroundConnection {
        return connection ?: run {
            val deferred = CompletableDeferred<ForegroundBinder>()
            val connection = bind(deferred)
            deferred.await()
            log.v("Bound Foreground")
            this.connection = connection
            connection
        }
    }

    private suspend fun bind(deferred: ConnectDeferred): ForegroundConnection {
        val ctx = context.requireAppContext()
        val intent = Intent(ctx, ForegroundService::class.java).apply {
            action = FOREGROUND_BINDER_ACTION
        }

        val connection = ForegroundConnection(deferred,
            onConnectionClosed = {
                this.connection = null
            })

        if (!ctx.bindService(intent, connection,
                Context.BIND_AUTO_CREATE or Context.BIND_ABOVE_CLIENT or Context.BIND_IMPORTANT
            )) {
            deferred.completeExceptionally(BlokadaException("Could not bindService()"))
        }
        return connection
    }

}

class ForegroundService: Service() {

    private val notification = NotificationService
    private var binder: ForegroundBinder? = null

    private var counter: Long = 0
    private var lastDenied: List<Host> = emptyList()
    private var tunnelStatus: TunnelStatus = TunnelStatus.off()

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        ContextService.setContext(this)
        updateNotification()
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? {
        if (FOREGROUND_BINDER_ACTION == intent?.action) {
            ContextService.setContext(this)
            binder = ForegroundBinder { counter, lastDenied, tunnelStatus ->
                this.counter = counter ?: this.counter
                this.lastDenied = lastDenied ?: this.lastDenied
                this.tunnelStatus = tunnelStatus ?: this.tunnelStatus
                updateNotification()
            }
            return binder
        }
        return null
    }

    private fun updateNotification() {
        val prototype = MonitorNotification(tunnelStatus, counter, lastDenied)
        val n = notification.build(prototype)
        startForeground(prototype.id, n)
    }

}

class ForegroundBinder(
    val onNewStats: (counter: Long?, lastDenied: List<Host>?, tunnelStatus: TunnelStatus?) -> Unit
) : Binder()

const val FOREGROUND_BINDER_ACTION = "ForegroundBinder"

private class ForegroundConnection(
    private val deferred: ConnectDeferred,
    val onConnectionClosed: () -> Unit
): ServiceConnection {

    private val log = Logger("ForegroundConnection")

    lateinit var binder: ForegroundBinder

    override fun onServiceConnected(name: ComponentName, binder: IBinder) {
        this.binder = binder as ForegroundBinder
        deferred.complete(this.binder)
    }

    override fun onServiceDisconnected(name: ComponentName?) {
        log.w("onServiceDisconnected")
        onConnectionClosed()
    }

}

private typealias ConnectDeferred = CompletableDeferred<ForegroundBinder>
