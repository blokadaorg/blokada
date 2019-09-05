package tunnel

import core.Kontext
import junit.framework.Assert
import org.junit.Test
import org.pcap4j.packet.UdpPacket
import org.pcap4j.packet.UnknownPacket
import org.pcap4j.packet.namednumber.UdpPort
import java.net.DatagramSocket
import java.net.InetAddress


class ForwarderTest {
    @Test
    fun forwarder_cannotGrowUnbound() {
        val forwarder = Forwarder(ttl = 500)
        val ktx = Kontext.forTest()

        forwarder.add(ktx, DatagramSocket(), mockPacket())
        Thread.sleep(400)

        Assert.assertEquals(1, forwarder.size())
        forwarder.add(ktx, DatagramSocket(), mockPacket())
        Thread.sleep(400)

        Assert.assertEquals(2, forwarder.size())
        forwarder.add(ktx, DatagramSocket(), mockPacket())
        Assert.assertEquals(2, forwarder.size())
    }

    private fun mockPacket() = UdpPacket.Builder()
            .srcPort(UdpPort.HTTP)
            .dstPort(UdpPort.HTTP)
            .srcAddr(InetAddress.getByAddress(byteArrayOf(8, 8, 4, 4)))
            .dstAddr(InetAddress.getByAddress(byteArrayOf(8, 8, 8, 8)))
            .correctChecksumAtBuild(true)
            .correctLengthAtBuild(true)
            .payloadBuilder(
                    UnknownPacket.Builder()
                            .rawData(byteArrayOf(1, 2, 3, 4, 5))
            ).build()
}
