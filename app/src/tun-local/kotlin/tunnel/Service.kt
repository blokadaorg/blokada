package tunnel

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.net.VpnService
import android.os.Binder
import android.os.IBinder
import android.os.ParcelFileDescriptor
import android.os.SystemClock
import com.github.michaelbull.result.mapError
import core.*
import kotlinx.coroutines.experimental.CompletableDeferred
import kotlinx.coroutines.experimental.delay
import kotlinx.coroutines.experimental.launch
import java.io.FileDescriptor

class ServiceBinder(
        val service: Service,
        var onClose: (ktx: Kontext) -> Unit = {},
        var onConfigure: (ktx: Kontext, vpn: VpnService.Builder) -> Time = { _, _ -> 0L }
) : Binder()

internal class ServiceConnector(
        var onClose: (ktx: Kontext) -> Unit = {},
        var onConfigure: (ktx: Kontext, vpn: VpnService.Builder) -> Time = { _, _ -> 0L }
) {

    private var deferred = CompletableDeferred<ServiceBinder>()

    private val serviceConnection = object: ServiceConnection {
        @Synchronized override fun onServiceConnected(name: ComponentName, binder: IBinder) {
            if (binder !is ServiceBinder) {
                "tunnel".ktx().e("service binder of wrong type", binder::class.java)
                return
            }
            val b = binder
            b.onClose = onClose
            b.onConfigure = onConfigure
            deferred.complete(b)
        }

        @Synchronized override fun onServiceDisconnected(name: ComponentName?) {
            deferred.completeExceptionally(Exception("service bind disconnected"))
        }
    }

    fun bind(ktx: AndroidKontext) = {
        this.deferred = CompletableDeferred()
        val intent = Intent(ktx.ctx, Service::class.java)
        intent.action = Service.BINDER_ACTION
        if (!ktx.ctx.bindService(intent, serviceConnection, Context.BIND_AUTO_CREATE
                or Context.BIND_ABOVE_CLIENT or Context.BIND_IMPORTANT)) {
            deferred.completeExceptionally(Exception("could not bind to service"))
        } else launch {
            delay(3000)
            if (!deferred.isCompleted) deferred.completeExceptionally(
                    Exception("timeout waiting for binding to service"))
        }
        deferred
    }()

    fun unbind(ktx: AndroidKontext) = Result.of { ktx.ctx.unbindService(serviceConnection) }
}

class Service : VpnService() {

    companion object Statics {
        val BINDER_ACTION = "Service"

        private var tunDescriptor: ParcelFileDescriptor? = null
        private var tunFd = -1
        private var lastReleasedMillis = 0L
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int =
            android.app.Service.START_STICKY

    private var binder: ServiceBinder? = null
    override fun onBind(intent: Intent?): IBinder? {
        if (BINDER_ACTION == intent?.action) {
            binder = ServiceBinder(this)
            return binder
        }
        return super.onBind(intent)
    }

    override fun onUnbind(intent: Intent?): Boolean {
        if (BINDER_ACTION == intent?.action) {
//            binder = null
            return true
        }
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        val ktx = "service:onDestroy".ktx()
        turnOff(ktx)
        binder?.onClose?.invoke(ktx)
        super.onDestroy()
    }

    override fun onRevoke() {
        val ktx = "service:onRevoke".ktx()
        turnOff(ktx)
        binder?.onClose?.invoke(ktx)
        super.onRevoke()
    }

    fun turnOn(ktx: Kontext): FileDescriptor {
        tunDescriptor = establishTunnel(ktx)
        if (tunDescriptor != null) {
            tunFd = tunDescriptor?.fd ?: -1
            ktx.v("vpn established")
        } else {
            ktx.e("failed establishing vpn, no permissions?")
            tunFd = -1
        }
        return tunDescriptor?.fileDescriptor!!
    }

    private fun establishTunnel(ktx: Kontext): ParcelFileDescriptor? {
        val tunnel = super.Builder()
        val cooldownMillis = binder?.onConfigure?.invoke(ktx, tunnel) ?: 0L

        val timeSinceLastReleased = SystemClock.uptimeMillis() - lastReleasedMillis - cooldownMillis
        if (timeSinceLastReleased < 0) {
            // To not trigger strange VPN bugs (establish not earlier than X sec after last release)
            lastReleasedMillis = 0
            Thread.sleep(0 - timeSinceLastReleased)
        }
        ktx.v("asking system for vpn")
        return tunnel.establish()
    }

    fun turnOff(ktx: Kontext) {
        if (tunDescriptor != null) {
            Result.of { tunDescriptor?.close() ?: Unit }
                    .mapError {
                        // I can't remember why we try it twice, but it probably matters
                        Result.of { tunDescriptor?.close() ?: Unit }
                    }
            lastReleasedMillis = SystemClock.uptimeMillis()
            tunDescriptor = null
            tunFd = -1
            ktx.v("closed vpn")
        }
    }

}
