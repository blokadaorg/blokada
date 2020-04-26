package tunnel

import android.net.VpnService
import core.e
import core.v
import core.w
import kotlinx.coroutines.experimental.runBlocking
import java.io.FileDescriptor
import java.net.DatagramSocket
import java.net.Socket

internal class TunnelManager(
    private val onVpnClose: (rejected: Boolean) -> Unit,
    private val onVpnConfigure: (VpnService.Builder) -> Unit,
    private val createTunnel: (CurrentTunnel, () -> DatagramSocket) -> Tunnel?,
    private val createConfigurator: (CurrentTunnel, ServiceBinder) -> Configurator
) {

    private var state: CurrentTunnel = CurrentTunnel()
    private var dirtyState: CurrentTunnel? = null

    private var tun: TunnelDescriptor? = null
    private var threadIndex: Int = 0

    private lateinit var configurator: Configurator
    private var connector = ServiceConnector(
        onClose = onVpnClose,
        onConfigure = {
            w("using unconfigured connector")
            0L
        }
    )

    fun setState(currentTunnel: CurrentTunnel) {
        dirtyState = currentTunnel
    }

    fun sync() {
        val proposed = dirtyState ?: return

        when {
            proposed == state -> {
                v("tunnel already in proposed state, doing nothing", proposed)
            }
            proposed.dnsServers.isEmpty() -> {
                v("no DNS servers set, turning off VPN tunnel (if it was on)")
                stop()
            }
            else -> {
                stop()
                v("starting tunnel in new state", proposed)
                start(proposed)
            }
        }

        state = proposed
    }

    private fun start(state: CurrentTunnel) {
        try {
            connector = createConnector()
            v("binding to connector")
            val binding = connector.bind()
            runBlocking { binding.join() }
            val binder = binding.getCompleted()
            configurator = createConfigurator(state, binder)
            v("turning on vpn service")
            val fd = binder.service.turnOn()
            val tunnelThread =
                startTunnelThread(state, fd, threadIndex++, createSocketFactory(binder))
            if (tunnelThread != null) {
                val (tunnel, thread) = tunnelThread
                tun = TunnelDescriptor(tunnel, thread, fd, binder)
            } else tun = TunnelDescriptor(null, null, fd, binder)
            v("started vpn service")
        } catch (ex: Exception) {
            e("failed starting vpn service", ex)
            onVpnClose(false)
            throw ex
        }
    }

    private fun startTunnelThread(
        state: CurrentTunnel, fd: FileDescriptor, index: Int,
        socketFactory: () -> DatagramSocket
    ): Pair<Tunnel, Thread>? {
        val tunnel = createTunnel(state, socketFactory)
        if (tunnel != null) {
            val tunnelThread = Thread({ tunnel.runWithRetry(fd) }, "tunnel-$index")
            tunnelThread.start()
            v("tunnel thread started", tunnelThread)
            return tunnel to tunnelThread
        } else {
            v("skipping tunnel thread, nothing configured")
            return null
        }
    }

    private fun stopTunnelThread(tunnel: Tunnel, thread: Thread) {
        v("stopping tunnel thread", thread.name)
        tunnel.stop()
        try {
            thread.interrupt()
        } catch (ex: Exception) {
            w("failed to interrupt tunnel thread", ex)
        }
        try {
            thread.join(5000)
        } catch (ex: Exception) {
            w("failed to join tunnel thread", ex)
        }
        v("tunnel thread stopped")
    }

    fun stop() {
        state = CurrentTunnel()
        val desc = tun
        if (desc == null) {
            w("no tunnel to stop, descriptor is null")
            return
        }
        if (desc.tunnel != null && desc.thread != null) stopTunnelThread(desc.tunnel, desc.thread)
        desc.binder.service.turnOff()
        connector.unbind()//.mapError { ex -> ktx.w("failed unbinding connector", ex) }
        tun = null
        v("vpn stopped")
    }

    private fun createConnector() = ServiceConnector(onVpnClose, onConfigure = { vpn ->
        configurator.configure(vpn)
        onVpnConfigure(vpn)
        5000L
    })

    private fun createSocketFactory(binder: ServiceBinder): () -> DatagramSocket = {
        val socket = DatagramSocket()
        val protected = binder.service.protect(socket)
        if (!protected) e("could not protect socket")
        socket
    }

    fun protect(socket: Socket) {
        if (tun == null) return
        else if (tun?.binder?.service?.protect(socket) != true) e("could not protect", socket)
    }

}
