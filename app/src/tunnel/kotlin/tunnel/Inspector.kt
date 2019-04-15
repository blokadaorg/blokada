package tunnel

import core.Kontext
import org.pcap4j.packet.*
import java.io.File

internal class Inspector {
    fun inspect(ktx: Kontext, packet: IpPacket) {
        var payload = packet.payload
        var protocol = ""
        var signature = ""
        if (packet.payload is UdpPacket) {
            protocol = "udp"
            payload = packet.payload as UdpPacket
            signature = "%s %s".format(
                toHex(packet.header.srcAddr.getAddress(), payload.header.srcPort.valueAsInt()),
                toHex(packet.header.dstAddr.getAddress(), payload.header.dstPort.valueAsInt())
            )
        } else if (packet.payload is TcpPacket) {
            protocol = "tcp"
            payload = packet.payload as TcpPacket
            signature = "%s %s".format(
                toHex(packet.header.srcAddr.getAddress(), payload.header.srcPort.valueAsInt()),
                toHex(packet.header.dstAddr.getAddress(), payload.header.dstPort.valueAsInt())
            )
        }

        if (protocol != "") {
            if (packet is IpV6Packet) protocol = protocol + "6"
            File("/proc/net/%s".format(protocol)).useLines {
                lines -> lines.forEach { line ->
                    if (signature in line) {
                        val tokens = line.split(" +".toRegex())
                        ktx.v("PACKET %s: src=%s, dst=%s, uid=%s".format(protocol.toUpperCase(), tokens[2], tokens[3], tokens[8]))
                    }
                }
            }
        }
    }

    private fun toHex(addr: ByteArray, port: Int) : String {
        val hexHost = addr.reversedArray().joinToString(separator="", transform={ x -> "%02X".format(x) })
        return "%s:%04X".format(hexHost, port)
    }
}
