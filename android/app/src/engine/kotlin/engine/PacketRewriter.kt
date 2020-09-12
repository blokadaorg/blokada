/*
 * This file is part of Blokada.
 *
 * Blokada is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Blokada is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Blokada.  If not, see <https://www.gnu.org/licenses/>.
 *
 * Copyright © 2020 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package engine

import android.system.ErrnoException
import android.system.OsConstants
import model.*
import org.pcap4j.packet.*
import org.pcap4j.packet.namednumber.UdpPort
import org.xbill.DNS.*
import ui.utils.cause
import utils.Logger
import java.io.IOException
import java.net.Inet4Address
import java.net.Inet6Address
import java.net.SocketException
import java.nio.ByteBuffer
import java.util.*
import kotlin.experimental.and

internal class PacketRewriter(
    private val loopback: () -> Any,
    private val errorOccurred: (BlokadaException) -> Any,
    private val buffer: ByteBuffer,
    private val filter: Boolean = true
) {

    private val log = Logger("Rewriter")
    private val filtering = FilteringService
    private val dns = DnsMapperService

    private var lastBlocked: Host = ""

    fun handleFromDevice(fromDevice: ByteArray, length: Int): Boolean {
        return interceptDns(fromDevice, length)
    }

    fun handleToDevice(destination: ByteBuffer, length: Int): Boolean {
        if (isUdp (destination) && (
                    srcAddress4(destination, dns.externalForIndex(0).address) ||
                            (dns.count() > 1 && srcAddress4(destination, dns.externalForIndex(1).address))
                    )
        ) {
            rewriteSrcDns4(destination, length)
            return true
        } else return false
    }

    private val ipv4Version = (1 shl 6).toByte()
    private val ipv6Version = (3 shl 5).toByte()

    private fun interceptDns(packetBytes: ByteArray, length: Int): Boolean {
        return if ((packetBytes[0] and ipv4Version) == ipv4Version) {
            if (isUdp(packetBytes) && dstAddress4(packetBytes, length, dnsProxyDst4))
                parseDns(packetBytes, length)
            else false
        } else if ((packetBytes[0] and ipv6Version) == ipv6Version) {
            log.w("ipv6 ad blocking not supported, passing through")
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
        return if (!filter || filtering.allowed(host) || !filtering.denied(host)) {
            val dnsIndex = packetBytes[19].toInt() - 1
            val dnsAddress = dns.externalForIndex(dnsIndex)

            val udpForward = UdpPacket.Builder(udp)
                .srcAddr(originEnvelope.header.srcAddr)
                .dstAddr(dnsAddress)
                .srcPort(udp.header.srcPort)
                .dstPort(dns.dstDnsPort())
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

            MetricsService.onDnsQueryStarted(udp.header.srcPort.value())

            false
        } else {
            if (lastBlocked != host) {
                // To not print the same name multiple times in a row
                lastBlocked = host
                log.v("Blocked: $host")
            }

            dnsMessage.header.setFlag(Flags.QR.toInt())
            dnsMessage.header.rcode = Rcode.NOERROR
            dnsMessage.addRecord(denyResponse, Section.AUTHORITY)
            toDeviceFakeDnsResponse(dnsMessage.toWire(), originEnvelope)
            true
        }
    }

    private fun rewriteSrcDns4(packet: ByteBuffer, length: Int) {
        val originEnvelope = try {
            IpSelector.newPacket(packet.array(), packet.arrayOffset(), length) as IpPacket
        } catch (e: Exception) {
            log.w("weird packet")
            return
        }

        originEnvelope as IpV4Packet

        if (originEnvelope.payload !is UdpPacket) {
            log.w("Non-UDP packet received from the DNS server, dropping")
            return
        }

        val udp = originEnvelope.payload as UdpPacket
        val udpRaw = udp.payload.rawData

        val origin = originEnvelope.header.srcAddr
        val addr = dns.externalToInternal(origin) as Inet4Address?
        if (addr == null) errorOccurred("cannot rewrite DNS response, unknown dns server: $origin. dropping".ex())
        else {
            val udpForward = UdpPacket.Builder(udp)
                .srcAddr(addr)
                .dstAddr(originEnvelope.header.dstAddr)
                .srcPort(UdpPort.DOMAIN)
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

            MetricsService.onDnsQueryFinished(udp.header.dstPort.value())
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
        destination.clear()
        destination.put(envelope.rawData)
        destination.rewind()
        destination.limit(envelope.rawData.size)
        loopback()
    }

}

// Returns true if the forwarding socket should be reconnected
fun handleForwardException(ex: Exception): Boolean {
    val c = ex.cause
    return when {
        c is ErrnoException && c.errno == OsConstants.ENETUNREACH -> {
            Logger.v("Rewriter", "Got ENETUNREACH, ignoring (probably no connection)")
            false
        }
        c is ErrnoException && c.errno == OsConstants.EINVAL -> {
            Logger.v("Rewriter", "Got EINVAL, reconnecting socket (probably switching network)")
            true
        }
        c is SocketException && c.message == "Pending connect failure" -> {
            Logger.v("Rewriter", "Got pending connect failure, reconnecting socket (probably switching network)")
            true
        }
        c is ErrnoException && c.errno == OsConstants.EPERM -> {
            Logger.e("Rewriter", "Got EPERM while forwarding packet")
            throw ex
        }
        else -> {
            Logger.w("Rewriter", "Failed forwarding packet, ignoring".cause(ex))
            false
        }
    }
}

private val denyResponse: SOARecord = SOARecord(
    Name("org.blokada.invalid."), DClass.IN,
    5L, Name("org.blokada.invalid."), Name("org.blokada.invalid."), 0, 0, 0, 0, 5
)

