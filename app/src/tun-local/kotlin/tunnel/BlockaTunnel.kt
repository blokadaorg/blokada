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
import org.pcap4j.packet.*
import org.pcap4j.packet.factory.PacketFactoryPropertiesLoader
import org.pcap4j.util.PropertiesLoader
import org.xbill.DNS.*
import java.io.*
import java.net.*
import java.nio.ByteBuffer
import java.util.*
import kotlin.experimental.and
import kotlin.math.min


internal class BlockaTunnel(
        private val dnsServers: List<InetSocketAddress>,
        private val powersave: Boolean,
        private val adblocking: Boolean,
        private val currentLease: CurrentLease,
        private val userBoringtunPrivateKey: String,
        private val doCreateSocket: () -> DatagramSocket,
        private val blockade: Blockade,
        private val denyResponse: SOARecord = SOARecord(Name("org.blokada.invalid."), DClass.IN,
                5L, Name("org.blokada.invalid."), Name("org.blokada.invalid."), 0, 0, 0, 0, 5)
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

    private val MAX_ONE_WAY_DNS_REQUESTS = 10
    private var oneWayDnsCounter = 0

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

    private fun errorOccurred(error: String) {
        e(error, errorsRecently)
        if (++errorsRecently > MAX_ERRORS) {
            errorsRecently = 0
            throw Exception("Too many errors recently", Exception(error))
        }
    }

    fun fromDevice(fromDevice: ByteArray, length: Int) {
        if (adblocking && interceptDns(fromDevice, length)) return

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
                    if (adblocking && isUdp (destination) && (
                                    srcAddress4(destination, dnsServers[0].address.address) ||
                                            (dnsServers.size > 1 && srcAddress4(destination, dnsServers[1].address.address))
                                    )
                    ) {
                        oneWayDnsCounter = 0
                        rewriteSrcDns4(destination, length)
                    }
                    loopback()
                }
                BoringTunJNI.WRITE_TO_TUNNEL_IPV6 -> loopback()
                else -> {
                    errorOccurred("read: wireguard unknown response: ${op[0].toInt()}")
                }
            }
        } while (response == BoringTunJNI.WRITE_TO_NETWORK)
    }

    private val ipv4Version = (1 shl 6).toByte()
    private val ipv6Version = (3 shl 5).toByte()

    private fun interceptDns(packetBytes: ByteArray, length: Int): Boolean {
        return if ((packetBytes[0] and ipv4Version) == ipv4Version) {
            if (isUdp(packetBytes) && dstAddress4(packetBytes, length, dnsProxyDst4))
                parseDns(packetBytes, length)
            else false
        } else if ((packetBytes[0] and ipv6Version) == ipv6Version) {
            w("ipv6 ad blocking not supported")
            false
        } else false
    }

    private fun parseDns(packetBytes: ByteArray, length: Int): Boolean {
        val originEnvelope = try {
            IpSelector.newPacket(packetBytes, 0, length) as IpPacket
        } catch (e: Exception) {
            return false
        }

        if (originEnvelope.payload !is UdpPacket) return false

        val udp = originEnvelope.payload as UdpPacket
        if (udp.payload == null) {
            // Some apps use empty UDP packets for something good
            return false
        }

        val udpRaw = udp.payload.rawData
        val dnsMessage = try {
            Message(udpRaw)
        } catch (e: IOException) {
            return false
        }
        if (dnsMessage.question == null) return false

        val host = dnsMessage.question.name.toString(true).toLowerCase(Locale.ENGLISH)
        return if (blockade.allowed(host) || !blockade.denied(host)) {
            val dnsIndex = packetBytes[19].toInt()
            val dnsAddress = dnsServers[dnsIndex - 1].address

            val udpForward = UdpPacket.Builder(udp)
                    .srcAddr(originEnvelope.header.srcAddr)
                    .dstAddr(dnsAddress)
                    .srcPort(udp.header.srcPort)
                    .dstPort(udp.header.dstPort)
                    .correctChecksumAtBuild(true)
                    .correctLengthAtBuild(true)
                    .payloadBuilder(UnknownPacket.Builder().rawData(udpRaw))

            val envelope = IpV4Packet.Builder(originEnvelope as IpV4Packet)
                    .srcAddr(originEnvelope.header.srcAddr as Inet4Address)
                    .dstAddr(dnsAddress as Inet4Address)
                    .correctChecksumAtBuild(true)
                    .correctLengthAtBuild(true)
                    .payloadBuilder(udpForward)
                    .build()

            envelope.rawData.copyInto(packetBytes)

            emit(TunnelEvents.REQUEST, Request(host))
            if (++oneWayDnsCounter > MAX_ONE_WAY_DNS_REQUESTS) {
                throw Exception("Too many DNS requests without response")
            }
            false
        } else {
            dnsMessage.header.setFlag(Flags.QR.toInt())
            dnsMessage.header.rcode = Rcode.NOERROR
            dnsMessage.addRecord(denyResponse, Section.AUTHORITY)
            toDeviceFakeDnsResponse(dnsMessage.toWire(), originEnvelope)
            emit(TunnelEvents.REQUEST, Request(host, blocked = true))
            true
        }
    }

    private fun dstAddress4(packet: ByteArray, length: Int, ip: ByteArray): Boolean {
        return (
                (packet[16] and ip[0]) == ip[0] &&
                        (packet[17] and ip[1]) == ip[1] &&
                        (packet[18] and ip[2]) == ip[2]
                )
    }

    private fun srcAddress4(packet: ByteBuffer, ip: ByteArray): Boolean {
        return (
                (packet[12] and ip[0]) == ip[0] &&
                        (packet[13] and ip[1]) == ip[1] &&
                        (packet[14] and ip[2]) == ip[2] &&
                        (packet[15] and ip[3]) == ip[3]
                )
    }

    private fun isUdp(packet: ByteBuffer): Boolean {
        return packet[9] == 17.toByte()
    }

    private fun isUdp(packet: ByteArray): Boolean {
        return packet[9] == 17.toByte()
    }

    private fun rewriteSrcDns4(packet: ByteBuffer, length: Int) {
        val originEnvelope = try {
            IpSelector.newPacket(packet.array(), packet.arrayOffset(), length) as IpPacket
        } catch (e: Exception) {
            return
        }

        originEnvelope as IpV4Packet

        if (originEnvelope.payload !is UdpPacket) {
            w("Non-UDP packet received from the DNS server, dropping")
            return
        }

        val udp = originEnvelope.payload as UdpPacket
        val udpRaw = udp.payload.rawData

        val dst = dnsServers.firstOrNull { it.address == originEnvelope.header.srcAddr }
        val dnsIndex = dnsServers.indexOf(dst)
        if (dnsIndex == -1) errorOccurred("cannot rewrite DNS response, unknown dns server: $dst. dropping")
//            ktx.v("rewritten back dns response")
        else {
            val src = dnsProxyDst4.copyOf()
            src[3] = (dnsIndex + 1).toByte()
            val addr = Inet4Address.getByAddress(src) as Inet4Address
            val udpForward = UdpPacket.Builder(udp)
                    .srcAddr(addr)
                    .dstAddr(originEnvelope.header.dstAddr)
                    .srcPort(udp.header.srcPort)
                    .dstPort(udp.header.dstPort)
                    .correctChecksumAtBuild(true)
                    .correctLengthAtBuild(true)
                    .payloadBuilder(UnknownPacket.Builder().rawData(udpRaw))

            val envelope = IpV4Packet.Builder(originEnvelope as IpV4Packet)
                    .srcAddr(addr)
                    .dstAddr(originEnvelope.header.dstAddr)
                    .correctChecksumAtBuild(true)
                    .correctLengthAtBuild(true)
                    .payloadBuilder(udpForward)
                    .build()

            packet.put(envelope.rawData)
            packet.position(0)
            packet.limit(envelope.rawData.size)
        }
    }

    private fun toDeviceFakeDnsResponse(response: ByteArray, originEnvelope: Packet?) {
        originEnvelope as IpPacket
        val udp = originEnvelope.payload as UdpPacket
        val udpResponse = UdpPacket.Builder(udp)
                .srcAddr(originEnvelope.header.dstAddr)
                .dstAddr(originEnvelope.header.srcAddr)
                .srcPort(udp.header.dstPort)
                .dstPort(udp.header.srcPort)
                .correctChecksumAtBuild(true)
                .correctLengthAtBuild(true)
                .payloadBuilder(UnknownPacket.Builder().rawData(response))

        val envelope: IpPacket
        if (originEnvelope is IpV4Packet) {
            envelope = IpV4Packet.Builder(originEnvelope)
                    .srcAddr(originEnvelope.header.dstAddr as Inet4Address)
                    .dstAddr(originEnvelope.header.srcAddr as Inet4Address)
                    .correctChecksumAtBuild(true)
                    .correctLengthAtBuild(true)
                    .payloadBuilder(udpResponse)
                    .build()
        } else {
            envelope = IpV6Packet.Builder(originEnvelope as IpV6Packet)
                    .srcAddr(originEnvelope.header.dstAddr as Inet6Address)
                    .dstAddr(originEnvelope.header.srcAddr as Inet6Address)
                    .correctLengthAtBuild(true)
                    .payloadBuilder(udpResponse)
                    .build()
        }

        val destination = buffer
        destination.rewind()
        destination.limit(destination.capacity())
        destination.put(envelope.rawData)
        destination.position(0)
        destination.limit(envelope.rawData.size)
        loopback()
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
        oneWayDnsCounter = 0
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


