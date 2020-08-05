package tunnel

import core.get
import core.w
import org.pcap4j.packet.*
import org.xbill.DNS.*
import java.io.IOException
import java.net.Inet4Address
import java.net.Inet6Address
import java.net.InetSocketAddress
import java.nio.ByteBuffer
import java.util.*
import kotlin.experimental.and

internal class BlockaTunnelFiltering(
        private val dnsServers: List<InetSocketAddress>,
        private val blockade: Blockade,
        private val loopback: () -> Any,
        private val errorOccurred: (String) -> Any,
        private val buffer: ByteBuffer
) {

    private val denyResponse: SOARecord = SOARecord(Name("org.blokada.invalid."), DClass.IN,
            5L, Name("org.blokada.invalid."), Name("org.blokada.invalid."), 0, 0, 0, 0, 5)

    private val MAX_ONE_WAY_DNS_REQUESTS = 10
    private var oneWayDnsCounter = 0

    fun handleFromDevice(fromDevice: ByteArray, length: Int): Boolean {
        return interceptDns(fromDevice, length)
    }

    fun handleToDevice(destination: ByteBuffer, length: Int): Boolean {
        if (isUdp (destination) && (
                        srcAddress4(destination, dnsServers[0].address.address) ||
                                (dnsServers.size > 1 && srcAddress4(destination, dnsServers[1].address.address))
                        )
        ) {
            rewriteSrcDns4(destination, length)
            oneWayDnsCounter = 0
            return true
        } else return false
    }

    fun restart() {
        oneWayDnsCounter = 0
    }

    private val ipv4Version = (1 shl 6).toByte()
    private val ipv6Version = (3 shl 5).toByte()

    private fun interceptDns(packetBytes: ByteArray, length: Int): Boolean {
        return if ((packetBytes[0] and ipv4Version) == ipv4Version) {
            if (isUdp(packetBytes) && dstAddress4(packetBytes, dnsProxyDst4))
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

            RequestLog.add(ExtendedRequest(host, requestId = dnsMessage.header.id))
            if (++oneWayDnsCounter > MAX_ONE_WAY_DNS_REQUESTS) {
                throw Exception("Too many DNS requests without response")
            }
            false
        } else {
            dnsMessage.header.setFlag(Flags.QR.toInt())
            dnsMessage.header.rcode = Rcode.NOERROR
            generateDnsAnswer(dnsMessage, denyResponse)
            toDeviceFakeDnsResponse(dnsMessage.toWire(), originEnvelope)
            RequestLog.add(ExtendedRequest(host, blocked = true))
            true
        }
    }

    private fun dstAddress4(packet: ByteArray, ip: ByteArray): Boolean {
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
            IpSelector.newPacket(packet.array(), packet.arrayOffset(), length) as IpV4Packet
        } catch (e: Exception) {
            return
        }

        if (originEnvelope.payload !is UdpPacket) {
            w("Non-UDP packet received from the DNS server, dropping")
            return
        }

        val udp = originEnvelope.payload as UdpPacket
        var udpRaw = udp.payload.rawData
        val dnsMessage = try {
            Message(udpRaw)
        } catch (e: IOException) {
            w("failed reading DNS answer", e)
            return
        }

        val updateDiff = ExtendedRequestDiff()
        updateDiff.rcode = dnsMessage.rcode

        if (dnsMessage.getSectionArray(Section.ANSWER).any { it is ARecord && it.address == unspecifiedIp4Addr }) {
            updateDiff.ip = unspecifiedIp4Addr
        } else if (dnsMessage.rcode == Rcode.NOERROR) {
            val answer = dnsMessage.getSectionArray(Section.ANSWER).find { it is ARecord } as ARecord? ?: return
            updateDiff.ip = answer.address

            if (get(TunnelConfig::class.java).cNameBlocking && dnsMessage.question.name != answer.name) {
                val cName = dnsMessage.question.name.toString(true)
                val cNamedDomain = answer.name.toString(true)

                if (!blockade.allowed(cName) && !blockade.allowed(cNamedDomain) && blockade.denied(cNamedDomain)) {
                    updateDiff.cnamedDomain = cNamedDomain
                    dnsMessage.header.setFlag(Flags.QR.toInt())
                    dnsMessage.header.rcode = Rcode.NOERROR
                    generateDnsAnswer(dnsMessage, denyResponse)
                    udpRaw = dnsMessage.toWire()
                }
            }
        }

        RequestLog.update({ it.requestId == dnsMessage.header.id }, updateDiff)

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

            val envelope = IpV4Packet.Builder(originEnvelope)
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

}
