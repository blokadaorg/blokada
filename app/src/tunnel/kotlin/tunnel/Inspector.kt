package tunnel

import core.Kontext
import org.pcap4j.packet.*
import java.io.File

internal class Inspector (
        private val label : String
    ) {
    fun inspect(ktx: Kontext, packet: IpPacket) {
        var protocol: String
        var src: String
        var dst: String
        var dst1 = ""
        when (packet.payload) {
            is UdpPacket -> {
                protocol = "udp"
                if (packet is IpV6Packet) protocol += "6"
                val payload = packet.payload as UdpPacket
                src = "%s:%04X".format(toHex(packet.header.srcAddr.getAddress()), payload.header.srcPort.valueAsInt())
                dst = "%s:%04X".format(toHex(packet.header.dstAddr.getAddress()), payload.header.dstPort.valueAsInt())
            }
            is TcpPacket -> {
                protocol = "tcp"
                if (packet is IpV6Packet) protocol += "6"
                val payload = packet.payload as TcpPacket
                src = "%s:%04X".format(toHex(packet.header.srcAddr.getAddress()), payload.header.srcPort.valueAsInt())
                dst = "%s:%04X".format(toHex(packet.header.dstAddr.getAddress()), payload.header.dstPort.valueAsInt())
            }
            is IcmpV4CommonPacket -> {
                protocol = "icmp"
                val payload = packet.payload.getRawData()
                val icmp_id = payload[5] * 256 + payload[4]
                src  = "%s:%04X".format(toHex(packet.header.srcAddr.getAddress()), icmp_id)
                dst  = "%s:%04X".format(toHex(packet.header.dstAddr.getAddress()), icmp_id)
                dst1 = "%s:%04X".format(toHex(packet.header.dstAddr.getAddress()), 0)
            }
            is IcmpV6CommonPacket -> {
                protocol = "icmp6"
                val payload = packet.payload.getRawData()
                val icmp_id = payload[5] * 256 + payload[4]
                src  = "%s:%04X".format(toHex(packet.header.srcAddr.getAddress()), icmp_id)
                dst  = "%s:%04X".format(toHex(packet.header.dstAddr.getAddress()), icmp_id)
                dst1 = "%s:%04X".format(toHex(packet.header.dstAddr.getAddress()), 0)
            }
            else -> return
        }

        ktx.v("PACKET %s: searching (proto:%s, src=%s, dst=%s)".format(label, protocol.toUpperCase(), src, dst))
        File("/proc/net/%s".format(protocol)).useLines {
            lines -> lines.forEach { line ->
                val tokens = line.split(" +".toRegex())
                if (
                    (tokens[2] == src) && (tokens[3] == dst || tokens[3] == dst1)
                ) {
                    ktx.v("PACKET %s: found (proto:%s, src=%s, dst=%s, uid=%s)".format(label, protocol.toUpperCase(), tokens[2], tokens[3], tokens[8]))
                }
            }
        }
    }

    private fun toHex(addr: ByteArray) : String {
        return addr.reversedArray().joinToString(separator="", transform={ x -> "%02X".format(x) })
    }
}
