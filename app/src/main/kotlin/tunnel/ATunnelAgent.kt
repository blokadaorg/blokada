package tunnel

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.net.VpnService
import android.os.Binder
import android.os.IBinder
import com.github.salomonbrys.kodein.instance
import com.github.salomonbrys.kodein.with
import gs.environment.Worker
import gs.environment.inject
import nl.komponents.kovenant.Promise
import nl.komponents.kovenant.deferred
import java.io.FileDescriptor
import java.net.DatagramSocket

/**
 * ATunnelAgent manages the state of the ATunnelService.
 */
class ATunnelAgent(val ctx: Context) {

    private val tunnelKctx by lazy { ctx.inject().with("tunnel").instance<Worker>() }

    private var events: ITunnelEvents? = null
    private var deferred = deferred<ATunnelBinder, Exception>(tunnelKctx)

    private val serviceConnection = object: ServiceConnection {
        @Synchronized override fun onServiceConnected(name: ComponentName, binder: IBinder) {
            val b = binder as ATunnelBinder
            b.events = events
            deferred.resolve(b)
        }

        @Synchronized override fun onServiceDisconnected(name: ComponentName?) {
            deferred.reject(Exception("service disconnected"))
        }
    }

    fun bind(events: ITunnelEvents): Promise<ATunnelBinder, Exception> {
        this.events = events
        this.deferred = deferred(tunnelKctx)
        val intent = Intent(ctx, ATunnelService::class.java)
        intent.setAction(ATunnelService.BINDER_ACTION)
        return when (ctx.bindService(intent, serviceConnection, Context.BIND_AUTO_CREATE
            or Context.BIND_ABOVE_CLIENT or Context.BIND_IMPORTANT)) {
            true -> deferred.promise
            else -> {
                deferred.reject(Exception("could not bind in TunnelAgent"))
                deferred.promise
            }
        }
    }

    fun unbind() {
        this.events = null
        try { ctx.unbindService(serviceConnection) } catch (e: Exception) {}
    }
}

class ATunnelBinder(
        val actions: ITunnelActions,
        var events: ITunnelEvents? = null
) : Binder()

interface ITunnelActions {
    fun turnOn(): Int
    fun turnOff()
    fun protect(socket: DatagramSocket): Boolean
    fun fd(): FileDescriptor?
}

interface ITunnelEvents {
    fun configure(builder: VpnService.Builder): Long
    fun revoked()
}
