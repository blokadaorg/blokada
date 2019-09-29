package tunnel

import android.os.ParcelFileDescriptor
import android.system.ErrnoException
import android.system.Os
import android.system.OsConstants
import android.system.StructPollfd
import blocka.CurrentLease
import blocka.blockaVpnMain
import com.cloudflare.app.boringtun.BoringTunJNI
import com.github.michaelbull.result.mapError
import com.github.salomonbrys.kodein.instance
import core.*
import org.pcap4j.packet.factory.PacketFactoryPropertiesLoader
import org.pcap4j.util.PropertiesLoader
import java.io.*
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.net.InetSocketAddress
import java.nio.ByteBuffer
import kotlin.math.min


internal class BlockaTunnel(
        dnsServers: List<InetSocketAddress>,
        blockade: Blockade,
        private val powersave: Boolean,
        private val adblocking: Boolean,
        private val currentLease: CurrentLease,
        private val userBoringtunPrivateKey: String,
        private val doCreateSocket: () -> DatagramSocket
): Tunnel {

    private var device: FileDescriptor? = null
    private var error: FileDescriptor? = null

    private var gatewaySocket: DatagramSocket? = null
    private var gatewayParcelFileDescriptor: ParcelFileDescriptor? = null

    private var cooldownCounter = 1
    private var epermCounter = 0

    private val MTU = 1600
    private val buffer = ByteBuffer.allocateDirect(MTU)
    private val memory = ByteArray(MTU)

    private val packet = DatagramPacket(memory, 0, 1)

    private var deviceOut: OutputStream? = null

    private var tunnel: Long? = null
    private val op = ByteBuffer.allocateDirect(8)
    private val empty = ByteArray(1)

    private val MAX_ERRORS = 50
    private val ERRORS_RESET_AFTER_TICKS = 60 /* 60 * 500 = 30 seconds */
    private var errorsRecently = 0

    private var lastTickMs = 0L
    private var ticks = 0
    private val tickIntervalMs = 500

    // TODO: Not the nicest
    private val tunnelEvents by lazy {
        val ctx = getActiveContext()!!
        val di = ctx.ktx("tunnel").di()
        di.instance<core.Tunnel>()
    }

    private val tunnelFiltering = BlockaTunnelFiltering(dnsServers, blockade, this::loopback,
            this::errorOccurred, buffer)

    private fun errorOccurred(error: String) {
        e(error, errorsRecently)
        if (++errorsRecently > MAX_ERRORS) {
            errorsRecently = 0
            throw Exception("Too many errors recently", Exception(error))
        }
    }

    fun fromDevice(fromDevice: ByteArray, length: Int) {
        if (adblocking && tunnelFiltering.handleFromDevice(fromDevice, length)) return

        var i = 0
        do {
            op.rewind()
            val destination = buffer
            destination.rewind()
            destination.limit(destination.capacity())
            val source = if (i++ == 0) fromDevice else empty
            val response = BoringTunJNI.wireguard_write(tunnel!!, source, length, destination,
                    destination.capacity(), op)
            destination.limit(response)
            when (op[0].toInt()) {
                BoringTunJNI.WRITE_TO_NETWORK -> {
                    forward()
                }
                BoringTunJNI.WIREGUARD_ERROR -> {
                    errorOccurred("wireguard error: ${BoringTunJNI.errors[response]}")
                }
                BoringTunJNI.WIREGUARD_DONE -> {
                    if (i == 1) e("did not do anything with packet, length: $length")
                }
                else -> {
                    errorOccurred("wireguard write unknown response: ${op[0].toInt()}")
                }
            }
        } while (response == BoringTunJNI.WRITE_TO_NETWORK)
    }

    fun toDevice(source: ByteArray, length: Int) {
        var i = 0
        do {
            op.rewind()
            val destination = buffer
            destination.rewind()
            destination.limit(destination.capacity())
            val source = if (i++ == 0) source else empty
            val response = BoringTunJNI.wireguard_read(tunnel!!, source, length, destination,
                    destination.capacity(), op)
            destination.limit(response) // TODO: what if -1
            when (op[0].toInt()) {
                BoringTunJNI.WRITE_TO_NETWORK -> {
                    forward()
                }
                BoringTunJNI.WIREGUARD_ERROR -> {
                    errorOccurred("read: wireguard error: ${BoringTunJNI.errors[response]}")
                }
                BoringTunJNI.WIREGUARD_DONE -> {
                    if (i == 1) e("read: did not do anything with packet: ${length} ${destination.limit()} ${destination.position()}")
                }
                BoringTunJNI.WRITE_TO_TUNNEL_IPV4 -> {
                    if (adblocking && tunnelFiltering.handleToDevice(destination, length)) {}
                    loopback()
                }
                BoringTunJNI.WRITE_TO_TUNNEL_IPV6 -> loopback()
                else -> {
                    errorOccurred("read: wireguard unknown response: ${op[0].toInt()}")
                }
            }
        } while (response == BoringTunJNI.WRITE_TO_NETWORK)
    }

    private fun createTunnel() {
        v("creating boringtun tunnel", currentLease.gatewayId)
        tunnel = BoringTunJNI.new_tunnel(userBoringtunPrivateKey, currentLease.gatewayId)
    }

    private fun forward() {
        val b = buffer
        packet.setData(b.array(), b.arrayOffset() + b.position(), b.limit())
        gatewaySocket!!.send(packet)
    }

    private fun loopback() {
        val b = buffer
        deviceOut?.write(b.array(), b.arrayOffset() + b.position(), b.limit()) ?: e("loopback not available")
    }

    fun openGatewaySocket() {
        gatewayParcelFileDescriptor?.close()
        gatewaySocket?.close()
        gatewaySocket = doCreateSocket()
        gatewaySocket?.connect(InetAddress.getByName(currentLease.gatewayIp), currentLease.gatewayPort)
        v("connect to gateway ip: ${currentLease.gatewayIp}")
    }

    override fun run(tunnel: FileDescriptor) {
        v("running boring tunnel thread", this)

        val input = FileInputStream(tunnel)
        val output = FileOutputStream(tunnel)
        deviceOut = output
        tunnelFiltering.restart()
        blockaVpnMain.syncIfNeeded()

        try {
            val errors = setupErrorsPipe()
            val device = setupDevicePipe(input)

            createTunnel()
            openGatewaySocket()
            val polls = setupPolls(errors, device)
            val gateway = polls[2]

            while (true) {
                if (threadInterrupted()) throw InterruptedException()

                device.listenFor(OsConstants.POLLIN)
                gateway.listenFor(OsConstants.POLLIN)

                poll(polls)
                tick()
//                fromLoopbackToDevice(ktx, device, output)
                fromDeviceToProxy(device, input)
                fromGatewayToProxy(gateway)
                //cleanup()
                cooldownCounter = 1
            }
        } catch (ex: InterruptedException) {
            v("tunnel thread interrupted", this, ex.toString())
            Thread.currentThread().interrupt()
            throw ex
        } catch (ex: Exception) {
            val cause = ex.cause
            if (cause is ErrnoException && cause.errno == OsConstants.EPERM) {
                if (++epermCounter >= 3 && powersave) {
                    emit(TunnelEvents.TUNNEL_POWER_SAVING)
                    epermCounter = 0
                }
            } else {
                epermCounter = 0
                e("failed tunnel thread", this, ex)
            }
            throw ex
        } finally {
            v("cleaning up resources", this)
            Result.of { Os.close(error) }
            Result.of { input.close() }
            Result.of { output.close() }
        }
    }

    override fun runWithRetry(tunnel: FileDescriptor) {
        var interrupted = false
        do {
            Result.of { run(tunnel) }.mapError {
                if (it is InterruptedException || threadInterrupted()) interrupted = true
                else {
                    emit(TunnelEvents.TUNNEL_RESTART)
                    val cooldown = min(cooldownTtl * cooldownCounter, cooldownMax)
                    cooldownCounter *= 2
                    e("tunnel thread error, will restart after $cooldown ms", this, it.toString())
                    tunnelEvents.tunnelState %= TunnelState.ACTIVATING
                    Result.of { Thread.sleep(cooldown) }.mapError {
                        if (it is InterruptedException || threadInterrupted()) interrupted = true
                    }
                    tunnelEvents.tunnelState %= TunnelState.ACTIVE
                }
            }
        } while (!interrupted)
        v("tunnel thread shutdown", this)
    }

    override fun stop() {
        Result.of { Os.close(error) }
        Result.of {
            v("closing gateway socket on stop")
            gatewayParcelFileDescriptor?.close()
            gatewaySocket?.close()
        }
        gatewayParcelFileDescriptor = null
        gatewaySocket = null
        deviceOut = null
        error = null
    }

    private fun setupErrorsPipe() = {
        val pipe = Os.pipe()
        error = pipe[0]
        val errors = StructPollfd()
        errors.fd = error
        errors.listenFor(OsConstants.POLLHUP or OsConstants.POLLERR)
        errors
    }()

    private fun setupDevicePipe(input: FileInputStream) = {
        this.device = input.fd
        val device = StructPollfd()
        device.fd = input.fd
        device
    }()

    private fun setupPolls(errors: StructPollfd, device: StructPollfd) = {
        val polls = arrayOfNulls<StructPollfd>(3) as Array<StructPollfd>
        polls[0] = errors
        polls[1] = device

        val parcel = ParcelFileDescriptor.fromDatagramSocket(gatewaySocket)
        val gateway = StructPollfd()
        gateway.fd = parcel.fileDescriptor
        polls[2] = gateway
        gatewayParcelFileDescriptor = parcel

        polls
    }()

    private fun poll(polls: Array<StructPollfd>) {
        while (true) {
            try {
                val result = Os.poll(polls, -1)
                if (result == 0) return
                if (polls[0].revents.toInt() != 0) throw InterruptedException("poll interrupted")
                break
            } catch (e: ErrnoException) {
                if (e.errno == OsConstants.EINTR) continue
                throw e
            }
        }
    }

    private fun fromDeviceToProxy(device: StructPollfd, input: InputStream) {
        if (device.isEvent(OsConstants.POLLIN)) {
            val length = input.read(memory, 0, MTU)
            if (length > 0) {
                fromDevice(memory, length)
            }
        }
    }

    private fun fromGatewayToProxy(gateway: StructPollfd) {
        if (gateway.isEvent(OsConstants.POLLIN)) {
            packet.setData(memory)
            gatewaySocket?.receive(packet) ?: e("no socket")
            toDevice(memory, packet.length)
        }
    }


    private fun tick() {
        // TODO: system current time called to often?
        val now = System.currentTimeMillis()
        if (now > (lastTickMs + tickIntervalMs)) {
            lastTickMs = now
            tickWireguard()
            ticks++

            if (ticks % ERRORS_RESET_AFTER_TICKS == 0) errorsRecently = 0
        }
    }

    fun tickWireguard() {
        if (tunnel == null) return

        op.rewind()
        val destination = buffer
        destination.rewind()
        destination.limit(destination.capacity())
        val response = BoringTunJNI.wireguard_tick(tunnel!!, destination, destination.capacity(), op)
        destination.limit(response)
        when (op[0].toInt()) {
            BoringTunJNI.WRITE_TO_NETWORK -> {
                forward()
            }
            BoringTunJNI.WIREGUARD_ERROR -> {
                errorOccurred("tick: wireguard error: ${BoringTunJNI.errors[response]}")
            }
            BoringTunJNI.WIREGUARD_DONE -> {
            }
            else -> {
                errorOccurred("tick: wireguard timer unknown response: ${op[0].toInt()}")
            }
        }
    }

    private fun threadInterrupted() = (Thread.interrupted() || this.error == null)

    private var count = 0
    private fun cleanup() {
        if (++count % 1024 == 0) {
            try {
                val l = PacketFactoryPropertiesLoader.getInstance()
                val field = l.javaClass.getDeclaredField("loader")
                field.isAccessible = true
                val loader = field.get(l) as PropertiesLoader
                loader.clearCache()
            } catch (e: Exception) {
            }
        }
    }

}

private fun StructPollfd.listenFor(events: Int) {
    this.events = events.toShort()
}

private fun StructPollfd.isEvent(event: Int): Boolean {
    return this.revents.toInt() and event != 0
}


