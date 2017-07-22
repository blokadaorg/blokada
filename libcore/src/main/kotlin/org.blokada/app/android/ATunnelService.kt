package org.blokada.app.android

import android.app.Service
import android.content.Intent
import android.net.VpnService
import android.os.IBinder
import android.os.ParcelFileDescriptor
import android.os.SystemClock
import com.github.salomonbrys.kodein.instance
import nl.komponents.kovenant.task
import org.blokada.framework.android.di
import java.io.FileDescriptor

/**
 * ATunnelService turns the tunnel on or off.
 *
 * This is a simple wrapper for actual (replaceable) tunnel (engine) logic, that is executed through
 * the binder.
 */
class ATunnelService : VpnService(), ITunnelActions {

    companion object Statics {
        val BINDER_ACTION = "ATunnelService"

        private var tunDescriptor: ParcelFileDescriptor? = null
        private var tunFd = -1
        private var lastReleasedMillis = 0L
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return Service.START_STICKY;
    }

    private var binder: ATunnelBinder? = null
    override fun onBind(intent: Intent?): IBinder? {
        if (ATunnelService.BINDER_ACTION.equals(intent?.action)) {
            binder = ATunnelBinder(this)
            return binder
        }
        return super.onBind(intent)
    }

    override fun onUnbind(intent: Intent?): Boolean {
        if (ATunnelService.BINDER_ACTION.equals(intent?.action)) {
//            binder = null
            return false
        }
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        turnOff()
        super.onDestroy()
    }

    override fun onRevoke() {
        turnOff()
        binder?.events?.revoked()
        super.onRevoke()
    }

    @Synchronized override fun turnOn(): Int {
        try {
            tunDescriptor = task {
                establishTunnelInternal()
            }.get()
            tunFd = tunDescriptor?.fd ?: -1
        } catch (e: Exception) {
            tunFd = -1
            throw e
        }
        return tunFd
    }

    @Synchronized override fun turnOff() {
        task {
            releaseTunnelInternal()
        } always {
            tunDescriptor = null
            tunFd = -1
        }
    }

    @Synchronized override fun fd(): FileDescriptor? {
        return tunDescriptor?.fileDescriptor
    }

    interface IBuilderConfigurator {
        fun configure(builder: VpnService.Builder)
    }

    private fun establishTunnelInternal(): ParcelFileDescriptor {
        val configurator: IBuilderConfigurator = di().instance()
        val tunnel = super<VpnService>.Builder()
        configurator.configure(tunnel)

        val cooldownMillis = binder?.events?.configure(tunnel) ?: 0L

        val timeSinceLastReleased = SystemClock.uptimeMillis() - lastReleasedMillis - cooldownMillis
        if (timeSinceLastReleased < 0) {
            // To not trigger strange VPN bugs (establish not earlier than X sec after last release)
            lastReleasedMillis = 0
            Thread.sleep(0 - timeSinceLastReleased)
        }
        val descriptor = tunnel.establish() ?: throw Exception("failed to establish tunnel")
        return descriptor
    }

    private fun releaseTunnelInternal() {
        when (tunDescriptor) {
            null -> return
            else -> {
                try {
                    tunDescriptor?.close()
                } catch (e: Exception) {
                } finally {
                    try {
                        tunDescriptor?.close()
                    } catch (e: Exception) {}
                    finally {
                        lastReleasedMillis = SystemClock.uptimeMillis()
                    }
                }
            }
        }
    }
}
