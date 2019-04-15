package tunnel

import core.Kontext
import org.pcap4j.packet.*
import java.io.File

internal class Inspector {
    fun inspect(ktx: Kontext, packet: IpPacket) {
        var protocol = ""
        var signature = ""
        when (packet.payload) {
            is UdpPacket -> {
                protocol = "udp"
                if (packet is IpV6Packet) protocol += "6"
                val payload = packet.payload as UdpPacket
                signature = "%s %s".format(
                    toHex(packet.header.srcAddr.getAddress(), payload.header.srcPort.valueAsInt()),
                    toHex(packet.header.dstAddr.getAddress(), payload.header.dstPort.valueAsInt())
                )
            }
            is TcpPacket -> {
                protocol = "tcp"
                if (packet is IpV6Packet) protocol += "6"
                val payload = packet.payload as TcpPacket
                signature = "%s %s".format(
                    toHex(packet.header.srcAddr.getAddress(), payload.header.srcPort.valueAsInt()),
                    toHex(packet.header.dstAddr.getAddress(), payload.header.dstPort.valueAsInt())
                )
            }
            is IcmpV4CommonPacket -> {
                protocol = "icmp"
                val payload = packet.payload.getRawData()
                val icmp_id = payload[5] * 256 + payload[4]
                signature = "%s %s".format(
                    toHex(packet.header.srcAddr.getAddress(), icmp_id),
                    toHex(packet.header.dstAddr.getAddress(), 0)
                )
            }
            is IcmpV6CommonPacket -> {
                protocol = "icmp6"
                val payload = packet.payload.getRawData()
                val icmp_id = payload[5] * 256 + payload[4]
                signature = "%s %s".format(
                    toHex(packet.header.srcAddr.getAddress(), icmp_id),
                    toHex(packet.header.dstAddr.getAddress(), 0)
                )
            }
            else -> return
        }

        File("/proc/net/%s".format(protocol)).useLines {
            lines -> lines.forEach { line ->
                if (signature in line) {
                    val tokens = line.split(" +".toRegex())
                    ktx.v("PACKET %s: src=%s, dst=%s, uid=%s".format(protocol.toUpperCase(), tokens[2], tokens[3], tokens[8]))
                }
            }
        }
    }

    private fun toHex(addr: ByteArray, port: Int) : String {
        val hexHost = addr.reversedArray().joinToString(separator="", transform={ x -> "%02X".format(x) })
        return "%s:%04X".format(hexHost, port)
    }
}
