package org.blokada.main

import org.pcap4j.packet.IpPacket
import java.net.DatagramPacket

interface IProxyEvents {
    fun forward(packet: DatagramPacket, request: IpPacket?)
    fun loopback(packet: IpPacket)
}
