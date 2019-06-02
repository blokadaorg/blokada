package tunnel

import com.cloudflare.app.boringtun.BoringTunJNI
import core.Kontext
import org.pcap4j.packet.*
import org.xbill.DNS.*
import java.io.IOException
import java.net.Inet4Address
import java.net.Inet6Address
import java.net.InetAddress
import java.net.InetSocketAddress
import java.nio.ByteBuffer
import java.util.*
import kotlin.experimental.and
import kotlin.collections.copyInto

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

    private var tunnel: Long? = null
    private val op = ByteBuffer.allocateDirect(8)
    private val empty = ByteArray(1)

    fun createTunnel(ktx: Kontext) {
        ktx.v("creating boringtun tunnel", config.gatewayId)
        tunnel = BoringTunJNI.new_tunnel(config.privateKey, config.gatewayId)
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
                    buffers.returnBuffer(destinationBufferId)
                }
                BoringTunJNI.WRITE_TO_TUNNEL_IPV4 -> {
                    if (config.adblocking &&
                            (srcAddress4(ktx, destination, dnsServers[0].address.address) ||
                            srcAddress4(ktx, destination, dnsServers[1].address.address))
                    ) {
//                        ktx.v("detected dns coming back")
                        rewriteSrcDns4(ktx, destination, length)
                    }
                    loopback(ktx, destinationBufferId)
                }
                BoringTunJNI.WRITE_TO_TUNNEL_IPV6 -> loopback(ktx, destinationBufferId)
                else -> {
                    ktx.w("read: wireguard unknown response: ${op[0].toInt()}")
                    buffers.returnBuffer(destinationBufferId)
                }
            }
        } while (response == BoringTunJNI.WRITE_TO_NETWORK)
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

    private val ipv4Version = (1 shl 6).toByte()
    private val ipv6Version = (3 shl 5).toByte()

    private fun interceptDns(ktx: Kontext, packetBytes: ByteArray, length: Int): Boolean {
        return if ((packetBytes[0] and ipv4Version) == ipv4Version) {
            if (dstAddress4(ktx, packetBytes, length, dnsProxyDst4)) parseDns(ktx, packetBytes, length)
            else false
        } else if ((packetBytes[0] and ipv6Version) == ipv6Version) {
            ktx.w("ipv6 ad blocking not supported")
            false
        } else false
    }

    private fun parseDns(ktx: Kontext, packetBytes: ByteArray, length: Int): Boolean {
//        ktx.v("detected dns request")
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

//            ktx.v("rewriting dns request")
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

    private fun dstAddress4(ktx: Kontext, packet: ByteArray, length: Int, ip: ByteArray): Boolean {
        return (
                (packet[16] and ip[0]) == ip[0] &&
                        (packet[17] and ip[1]) == ip[1] &&
                        (packet[18] and ip[2]) == ip[2]
                )
    }

    private fun srcAddress4(ktx: Kontext, packet: ByteBuffer, ip: ByteArray): Boolean {
        return (
                (packet[12] and ip[0]) == ip[0] &&
                        (packet[13] and ip[1]) == ip[1] &&
                        (packet[14] and ip[2]) == ip[2] &&
                        (packet[15] and ip[3]) == ip[3]
                )
    }

    private fun rewriteSrcDns4(ktx: Kontext, packet: ByteBuffer, length: Int) {
        val originEnvelope = try {
            IpSelector.newPacket(packet.array(), packet.arrayOffset(), length) as IpPacket
        } catch (e: Exception) {
            return
        }

        originEnvelope as IpV4Packet

        if (originEnvelope.payload !is UdpPacket) {
            ktx.w("TCP packet received towards DNS IP")
            return
        }

        val udp = originEnvelope.payload as UdpPacket
        val udpRaw = udp.payload.rawData

        val dst = dnsServers.firstOrNull { it.address == originEnvelope.header.srcAddr }
        val dnsIndex = dnsServers.indexOf(dst)
        if (dnsIndex == -1) ktx.e("unknown dns server $dst")
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
//            ktx.v("rewritten back dns response")
        }
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
}
