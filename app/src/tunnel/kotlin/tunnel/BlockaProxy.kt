package tunnel

import com.cloudflare.app.boringtun.BoringTunJNI
import core.Kontext
import core.getExternalPath
import org.pcap4j.packet.*
import org.xbill.DNS.*
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.net.Inet4Address
import java.net.Inet6Address
import java.net.InetSocketAddress
import java.nio.ByteBuffer
import java.util.*

interface Proxy {
    fun fromDevice(ktx: Kontext, packetBytes: ByteArray, length: Int)
    fun toDevice(ktx: Kontext, response: ByteArray, length: Int, originEnvelope: Packet? = null)
}

internal class BlockaProxy(
        private val dnsServers: List<InetSocketAddress>,
        private val blockade: Blockade,
        private val config: BlockaConfig,
        private val buffers: Buffers,
        internal var forward: (Kontext, Int) -> Unit = { ktx, _ ->  ktx.w("forward not set")},
        internal var loopback: (Kontext, Int) -> Unit = { ktx, _ ->  ktx.w("loopback not set")},
        private val denyResponse: SOARecord = SOARecord(Name("org.blokada.invalid."), DClass.IN,
                5L, Name("org.blokada.invalid."), Name("org.blokada.invalid."), 0, 0, 0, 0, 5)
) : Proxy {

    private var droppedPackets: FileOutputStream? = try {
        val path = File(getExternalPath(), "dropped-packets")
        FileOutputStream(path, true)
    } catch (ex: Exception) {
        null
    }

    private var tunnel: Long? = null
    private val op = ByteBuffer.allocateDirect(8)
    private val empty = ByteArray(1)

    fun createTunnel(ktx: Kontext) {
        ktx.v("creating boringtun tunnel", config.gatewayId)
        tunnel = BoringTunJNI.new_tunnel(config.privateKey, config.gatewayId)
    }

    private fun interceptDns(ktx: Kontext, packetBytes: ByteArray, length: Int): Boolean {
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
            ktx.emit(Events.REQUEST, Request(host))
            false
        } else {
            dnsMessage.header.setFlag(Flags.QR.toInt())
            dnsMessage.header.rcode = Rcode.NOERROR
            dnsMessage.addRecord(denyResponse, Section.AUTHORITY)
            toDeviceFakeDnsResponse(ktx, dnsMessage.toWire(), originEnvelope)
            ktx.emit(Events.REQUEST, Request(host, blocked = true))
            true
        }
    }

    override fun fromDevice(ktx: Kontext, fromDevice: ByteArray, length: Int) {
        if (config.adblocking && interceptDns(ktx, fromDevice, length)) return

        var i = 0
        do {
            op.rewind()
            val destinationId = buffers.getFreeBuffer()
            val destination = buffers[destinationId]
            val source = if (i++ == 0) fromDevice else empty
            val response = BoringTunJNI.wireguard_write(tunnel!!, source, length, destination,
                    destination.capacity(), op)
            destination.limit(response)
            when (op[0].toInt()) {
                BoringTunJNI.WRITE_TO_NETWORK -> {
//                    ktx.v("will write to network: $response, buffer: ${destinationId}")
                    forward(ktx, destinationId)
                }
                BoringTunJNI.WIREGUARD_ERROR -> {
                    ktx.e("wireguard error: ${BoringTunJNI.errors[response]}")
                    buffers.returnBuffer(destinationId)
                }
                BoringTunJNI.WIREGUARD_DONE -> {
                    if (i == 1) ktx.e("did not do anything with packet: ${length} ${destination.limit()} ${destination.position()}")
//                    droppedPackets?.write(fromDevice, 0, length)
                    buffers.returnBuffer(destinationId)
                }
                else -> {
                    ktx.w("wireguard write unknown response: ${op[0].toInt()}")
                    buffers.returnBuffer(destinationId)
                }
            }
        } while (response == BoringTunJNI.WRITE_TO_NETWORK)
    }

    override fun toDevice(ktx: Kontext, source: ByteArray, length: Int, originEnvelope: Packet?) {
        var i = 0
        do {
            op.rewind()
//            ktx.v("read: received length: $length")
            val destinationBufferId = buffers.getFreeBuffer()
            val destination = buffers[destinationBufferId]
            val source = if (i++ == 0) source else empty
            val response = BoringTunJNI.wireguard_read(tunnel!!, source, length, destination,
                    destination.capacity(), op)
            destination.limit(response) // TODO: what if -1
            when (op[0].toInt()) {
                BoringTunJNI.WRITE_TO_NETWORK -> {
//                    ktx.v("read: will write: $response, length: $length")
                    forward(ktx, destinationBufferId)
                }
                BoringTunJNI.WIREGUARD_ERROR -> {
                    ktx.e("read: wireguard error: ${BoringTunJNI.errors[response]}")
                    buffers.returnBuffer(destinationBufferId)
                }
                BoringTunJNI.WIREGUARD_DONE -> {
                    if (i == 1) ktx.e("read: did not do anything with packet: ${length} ${destination.limit()} ${destination.position()}")
//                    droppedPackets?.write(source, 0, length)
                    buffers.returnBuffer(destinationBufferId)
                }
                BoringTunJNI.WRITE_TO_TUNNEL_IPV4,
                BoringTunJNI.WRITE_TO_TUNNEL_IPV6 -> loopback(ktx, destinationBufferId)
                else -> {
                    ktx.w("read: wireguard unknown response: ${op[0].toInt()}")
                    buffers.returnBuffer(destinationBufferId)
                }
            }
        } while (response == BoringTunJNI.WRITE_TO_NETWORK)
    }

    private fun toDeviceFakeDnsResponse(ktx: Kontext, response: ByteArray, originEnvelope: Packet?) {
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

        val destinationBufferId = buffers.getFreeBuffer()
        val destination = buffers[destinationBufferId]
        destination.put(envelope.rawData)
        destination.position(0)
        destination.limit(envelope.rawData.size)
        loopback(ktx, destinationBufferId)
    }

    fun tick(ktx: Kontext) {
        if (tunnel == null) return

        op.rewind()
        val destinationBufferId = buffers.getFreeBuffer()
        val destination = buffers[destinationBufferId]
        val response = BoringTunJNI.wireguard_tick(tunnel!!, destination, destination.capacity(), op)
        destination.limit(response)
        when (op[0].toInt()) {
            BoringTunJNI.WRITE_TO_NETWORK -> {
//                ktx.v("tick: write: $response")
                forward(ktx, destinationBufferId)
            }
            BoringTunJNI.WIREGUARD_ERROR -> {
                buffers.returnBuffer(destinationBufferId)
                ktx.e("tick: wireguard error: ${BoringTunJNI.errors[response]}")
            }
            BoringTunJNI.WIREGUARD_DONE -> {
                buffers.returnBuffer(destinationBufferId)
            }
            else -> {
                buffers.returnBuffer(destinationBufferId)
                ktx.w("tick: wireguard timer unknown response: ${op[0].toInt()}")
            }
        }
    }
}
