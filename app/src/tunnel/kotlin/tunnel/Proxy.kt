package tunnel

import android.system.ErrnoException
import android.system.OsConstants
import com.github.michaelbull.result.mapError
import core.Kontext
import core.Result
import org.pcap4j.packet.*
import org.xbill.DNS.*
import java.io.IOException
import java.net.*
import java.util.*

internal class Proxy(
        private val dnsServers: List<InetAddress>,
        private val blockade: Blockade,
        private val forwarder: Forwarder,
        private val loopback: Queue<ByteArray>,
        private val denyResponse: SOARecord = SOARecord(Name("org.blokada.invalid."), DClass.IN,
                5L, Name("org.blokada.invalid."), Name("org.blokada.invalid."), 0, 0, 0, 0, 5),
        private val doCreateSocket: () -> DatagramSocket = { DatagramSocket() }
) {

    fun fromDevice(ktx: Kontext, packetBytes: ByteArray) {
        val originEnvelope = try {
            IpSelector.newPacket(packetBytes, 0, packetBytes.size) as IpPacket
        } catch (e: Exception) {
            ktx.w("failed reading origin packet", e)
            return
        }

        if (originEnvelope.payload !is UdpPacket) return

        // DNS requests come addressed to our fake DNS server
        val destination = resolveActualDestination(originEnvelope)
        val udp = originEnvelope.payload as UdpPacket

        if (udp.payload == null) {
            // Some apps use empty UDP packets for something good
            val proxiedUdp = DatagramPacket(ByteArray(0), 0, 0, destination,
                    udp.header.dstPort.valueAsInt())
            forward(ktx, proxiedUdp)
            return
        }

        val udpRaw = udp.payload.rawData
        val dnsMessage = try {
            Message(udpRaw)
        } catch (e: IOException) {
            ktx.w("failed reading DNS message", e)
            return
        }
        if (dnsMessage.question == null) return

        val host = dnsMessage.question.name.toString(true).toLowerCase(Locale.ENGLISH)
        if (blockade.allowed(host) || !blockade.denied(host)) {
            val proxiedDns = DatagramPacket(udpRaw, 0, udpRaw.size, destination,
                    udp.header.dstPort.valueAsInt())
            forward(ktx, proxiedDns, originEnvelope)
        } else {
            dnsMessage.header.setFlag(Flags.QR.toInt())
            dnsMessage.header.rcode = Rcode.NOERROR
            dnsMessage.addRecord(denyResponse, Section.AUTHORITY)
            toDevice(ktx, dnsMessage.toWire(), originEnvelope)
            ktx.emit(Events.BLOCKED, host)
        }
    }

    fun toDevice(ktx: Kontext, response: ByteArray, originEnvelope: Packet) {
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
        loopback(ktx, envelope.rawData)
    }

    private fun forward(ktx: Kontext, udp: DatagramPacket, originEnvelope: IpPacket? = null) {
        val socket = doCreateSocket()
        Result.of {
            socket.send(udp)
            if (originEnvelope != null) forwarder.add(ktx, socket, originEnvelope)
            else Result.of { socket.close() }
        }.mapError { ex ->
            ktx.w("failed sending forwarded udp", ex.message ?: "")
            Result.of { socket.close() }
            val cause = ex.cause
            if (cause is ErrnoException && cause.errno == OsConstants.EPERM) throw ex
        }
    }

    private fun loopback(ktx: Kontext, response: ByteArray) = loopback.add(response)

    private fun resolveActualDestination(packet: IpPacket): InetAddress {
        val servers = dnsServers
        val current = packet.header.dstAddr
        return when {
            servers.isEmpty() -> current
            else -> try {
                // Last octet of DNS server IP corresponds to its index
                val index = current.address.last() - 2
                servers[index]
            } catch (e: Exception) {
                current
            }
        }
    }
}

internal fun DatagramPacket.toNiceString(): String {
    return this.socketAddress.toString()
}

