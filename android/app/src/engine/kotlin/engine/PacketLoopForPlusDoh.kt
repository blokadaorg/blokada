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

import android.os.ParcelFileDescriptor
import android.system.ErrnoException
import android.system.Os
import android.system.OsConstants
import android.system.StructPollfd
import com.cloudflare.app.boringtun.BoringTunJNI
import model.BlokadaException
import model.GatewayId
import model.ex
import org.pcap4j.packet.*
import org.pcap4j.packet.factory.PacketFactoryPropertiesLoader
import org.pcap4j.util.PropertiesLoader
import ui.utils.cause
import utils.Logger
import java.io.FileDescriptor
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.InputStream
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.Inet6Address
import java.net.InetAddress
import java.nio.ByteBuffer


internal class PacketLoopForPlusDoh (
    private val deviceIn: FileInputStream,
    private val deviceOut: FileOutputStream,
    private val userBoringtunPrivateKey: String,
    internal val gatewayId: GatewayId,
    private val gatewayIp: String,
    private val gatewayPort: Int,
    private val createSocket: () -> DatagramSocket,
    private val stoppedUnexpectedly: () -> Unit
): Thread("PacketLoopForPlusDoh") {

    private val log = Logger("PLPlusDoh")

    // Constants
    private val MAX_ERRORS = 20
    private val ERRORS_RESET_AFTER_TICKS = 20 /* 20 * 500 = 10 seconds */
    private val MTU = 1600
    private val TICK_INTERVAL_MS = 500

    private val forwarder: Forwarder = Forwarder()

    // Memory buffers
    private val buffer = ByteBuffer.allocateDirect(2000)
    private val memory = ByteArray(MTU)
    private val packet = DatagramPacket(memory, 0, 1)
    private val op = ByteBuffer.allocateDirect(8)

    private val proxyMemory = ByteArray(MTU)
    private val proxyPacket = DatagramPacket(proxyMemory, 0, 1)

    private var boringtunHandle: Long = -1L
    private var devicePipe: FileDescriptor? = null
    private var errorPipe: FileDescriptor? = null

    private var gatewaySocket: DatagramSocket? = null
    private var gatewayParcelFileDescriptor: ParcelFileDescriptor? = null

    private var errorsRecently = 0

    private var lastTickMs = 0L
    private var ticks = 0

    private val rewriter = PacketRewriter(this::loopback, this::errorOccurred, buffer)

    private fun createTunnel() {
        log.v("Creating boringtun tunnel for gateway: $gatewayId")
        boringtunHandle = BoringTunJNI.new_tunnel(userBoringtunPrivateKey, gatewayId)
    }

    override fun run() {
        log.v("Started packet loop thread: $this")

        try {
            val errors = setupErrorsPipe()
            val device = setupDevicePipe(deviceIn)

            createTunnel()

            openGatewaySocket()
            val gatewayPipe = setupGatewayPipe()

            while (true) {
                if (shouldInterruptLoop()) throw InterruptedException()

                val polls = setupPolls(errors, device, gatewayPipe)
                val gateway = polls[2]

                device.listenFor(OsConstants.POLLIN)
                gateway.listenFor(OsConstants.POLLIN)

                poll(polls)
                tick()

                fromOpenProxySockets(polls)
                fromDeviceToProxy(device, deviceIn)
                fromGatewayToProxy(gateway)
                purge()
            }
        } catch (ex: InterruptedException) {
            log.v("Tunnel thread interrupted, stopping")
        } catch (ex: Exception) {
            log.w("Unexpected failure, stopping (maybe just closed?): $this: ${ex.message}")
        } finally {
            cleanup()
            if (!isInterrupted) stoppedUnexpectedly()
        }
    }

    private fun fromDevice(fromDevice: ByteArray, length: Int) {
        if (rewriter.handleFromDevice(fromDevice, length)) return

        if (dstAddress4(fromDevice, length, DnsMapperService.proxyDnsIpBytes)) {
            try {
                // Forward localhost packets to our DNS proxy
                val originEnvelope = IpSelector.newPacket(fromDevice, 0, length) as IpPacket
                (originEnvelope.payload as? UdpPacket)?.let { udp ->
                    udp.payload?.let { payload ->
                        val proxiedDns = DatagramPacket(
                            payload.rawData, 0, payload.length(),
                            originEnvelope.header.dstAddr,
                            udp.header.dstPort.valueAsInt()
                        )
                        forwardLocally(proxiedDns, originEnvelope)
                        return
                    }
                }
            } catch (ex: Exception) {
                log.w("Failed reading packet: ${ex.message}")
            }
        }

        op.rewind()
        val destination = buffer
        destination.rewind()
        destination.limit(destination.capacity())
        val response = BoringTunJNI.wireguard_write(boringtunHandle, fromDevice, length, destination,
            destination.capacity(), op)
        destination.limit(response)
        val opCode = op[0].toInt()
        when (opCode) {
            BoringTunJNI.WRITE_TO_NETWORK -> {
                forwardToGateway()
            }
            BoringTunJNI.WIREGUARD_ERROR -> {
                errorOccurred("Wireguard error: ${BoringTunJNI.errors[response]}".ex())
            }
            BoringTunJNI.WIREGUARD_DONE -> {
//                log.e("Packet dropped, length: $length")
                errorOccurred("Packet dropped, length: $length".ex())
            }
            else -> {
                errorOccurred("Wireguard write unknown response: $opCode".ex())
            }
        }
    }

    private fun toDeviceFromGateway(source: ByteArray, length: Int) {
        var i = 0
        do {
            op.rewind()
            val destination = buffer
            destination.rewind()
            destination.limit(destination.capacity())
            val response = BoringTunJNI.wireguard_read(
                boringtunHandle,
                source,
                if (i++ == 0) length else 0,
                destination,
                destination.capacity(),
                op
            )
            destination.limit(response) // TODO: what if -1
            val opCode = op[0].toInt()
            when (opCode) {
                BoringTunJNI.WRITE_TO_NETWORK -> {
                    forwardToGateway()
                }
                BoringTunJNI.WIREGUARD_ERROR -> {
                    errorOccurred("toDevice: wireguard error: ${BoringTunJNI.errors[response]}".ex())
                }
                BoringTunJNI.WIREGUARD_DONE -> {
//                    if (i == 1) log.e("toDevice: packet dropped, length: $length")
                    errorOccurred("toDevice: packet dropped, length: $length".ex())
                }
                BoringTunJNI.WRITE_TO_TUNNEL_IPV4 -> {
                    //if (adblocking) tunnelFiltering.handleToDevice(destination, length)
                    rewriter.handleToDevice(destination, length)
                    loopback()
                }
                BoringTunJNI.WRITE_TO_TUNNEL_IPV6 -> loopback()
                else -> {
                    errorOccurred("toDevice: wireguard unknown response: $opCode".ex())
                }
            }
        } while (opCode == BoringTunJNI.WRITE_TO_NETWORK)
    }

    private fun toDeviceFromProxy(source: ByteArray, length: Int, originEnvelope: Packet) {
        originEnvelope as IpPacket

        val udp = originEnvelope.payload as UdpPacket
        val udpResponse = UdpPacket.Builder(udp)
            .srcAddr(originEnvelope.header.dstAddr)
            .dstAddr(originEnvelope.header.srcAddr)
            .srcPort(udp.header.dstPort)
            .dstPort(udp.header.srcPort)
            .correctChecksumAtBuild(true)
            .correctLengthAtBuild(true)
            .payloadBuilder(UnknownPacket.Builder().rawData(source))
            .length(length.toShort())

        val envelope: IpPacket
        if (originEnvelope is IpV4Packet) {
            envelope = IpV4Packet.Builder(originEnvelope)
                .srcAddr(originEnvelope.header.dstAddr)
                .dstAddr(originEnvelope.header.srcAddr)
                .correctChecksumAtBuild(true)
                .correctLengthAtBuild(true)
                .payloadBuilder(udpResponse)
                .build()
        } else {
            log.w("ipv6 not supported")
            envelope = IpV6Packet.Builder(originEnvelope as IpV6Packet)
                .srcAddr(originEnvelope.header.dstAddr as Inet6Address)
                .dstAddr(originEnvelope.header.srcAddr as Inet6Address)
                .correctLengthAtBuild(true)
                .payloadBuilder(udpResponse)
                .build()
        }

        buffer.clear()
        buffer.put(envelope.rawData)
        buffer.rewind()
        buffer.limit(envelope.rawData.size)

        rewriter.handleToDevice(buffer, envelope.rawData.size)

        loopback()
    }

    private fun forwardToGateway() {
        val b = buffer
        packet.setData(b.array(), b.arrayOffset() + b.position(), b.limit())
        try {
            gatewaySocket!!.send(packet)
        } catch (ex: Exception) {
            if (handleForwardException(ex)) {
                sleep(500)
                // this did not work for some reason
//                closeGatewaySocket()
//                openGatewaySocket()
                throw BlokadaException("Requires thread restart: ${ex.message}")
            }
        }
    }

    private fun forwardLocally(udp: DatagramPacket, originEnvelope: IpPacket) {
        val socket = createSocket()
        try {
            socket.send(udp)
            forwarder.add(socket, originEnvelope)
        } catch (ex: Exception) {
            try { socket.close() } catch (ex: Exception) {}
            handleForwardException(ex)
        }
    }

    private fun loopback() {
        val b = buffer
        deviceOut.write(b.array(), b.arrayOffset() + b.position(), b.limit())
    }

    private fun openGatewaySocket() {
        gatewaySocket = createSocket()
        gatewaySocket?.connect(InetAddress.getByName(gatewayIp), gatewayPort)
        log.v("Connect to gateway ip: $gatewayIp")
    }

    private fun closeGatewaySocket() {
        log.w("Closing gateway socket")
        try { gatewayParcelFileDescriptor?.close() }  catch (ex: Exception) {}
        try { gatewaySocket?.close() } catch (ex: Exception) {}
        gatewayParcelFileDescriptor = null
        gatewaySocket = null
    }

    private fun setupErrorsPipe() = {
        val pipe = Os.pipe()
        errorPipe = pipe[0]
        val errors = StructPollfd()
        errors.fd = errorPipe
        errors.listenFor(OsConstants.POLLHUP or OsConstants.POLLERR)
        errors
    }()

    private fun setupDevicePipe(input: FileInputStream) = {
        this.devicePipe = input.fd
        val device = StructPollfd()
        device.fd = input.fd
        device
    }()

    private fun setupGatewayPipe() = {
        val parcel = ParcelFileDescriptor.fromDatagramSocket(gatewaySocket)
        val gateway = StructPollfd()
        gateway.fd = parcel.fileDescriptor
        gatewayParcelFileDescriptor = parcel
        gateway
    }()

    private fun setupPolls(errors: StructPollfd, device: StructPollfd, gateway: StructPollfd) = {
        val polls = arrayOfNulls<StructPollfd>(3 + forwarder.size()) as Array<StructPollfd>
        polls[0] = errors
        polls[1] = device
        polls[2] = gateway

        var i = 0
        while (i < forwarder.size()) {
            polls[3 + i] = forwarder[i].pipe
            i++
        }

        polls
    }()

    private fun poll(polls: Array<StructPollfd>) {
        while (true) {
            try {
                val result = Os.poll(polls, -1)
                if (result == 0) return
                if (polls[0].revents.toInt() != 0) {
                    log.w("Poll interrupted")
                    throw InterruptedException()
                }
                break
            } catch (e: ErrnoException) {
                if (e.errno == OsConstants.EINTR) continue
                throw e
            }
        }
    }

    private fun fromDeviceToProxy(device: StructPollfd, input: InputStream) {
        if (device.isEvent(OsConstants.POLLIN)) {
            try {
                val length = input.read(proxyMemory, 0, MTU)
                if (length > 0) {
                    fromDevice(proxyMemory, length)
                }
            } catch (ex: Exception) {
                // It's safe to ignore read errors if we are just stopping the thread
                if (!isInterrupted) throw ex
            }
        }
    }

    private fun fromGatewayToProxy(gateway: StructPollfd) {
        if (gateway.isEvent(OsConstants.POLLIN)) {
            packet.setData(memory)
            gatewaySocket?.receive(packet) ?: log.e("No gateway socket")
            toDeviceFromGateway(memory, packet.length)
        }
    }

    private fun fromOpenProxySockets(polls: Array<StructPollfd>) {
        var index = 0
        val iterator = forwarder.iterator()
        while (iterator.hasNext()) {
            val rule = iterator.next()
            if (polls[3 + index++].isEvent(OsConstants.POLLIN)) {
                iterator.remove()
                try {
                    proxyPacket.setData(proxyMemory)
                    rule.socket.receive(proxyPacket)
                    toDeviceFromProxy(proxyMemory, proxyPacket.length, rule.originEnvelope)
                } catch (ex: Exception) {
                    log.w("Failed receiving socket".cause(ex))
                }

                forwarder.closeRule(rule)
            }
        }
    }

    private fun tick() {
        // TODO: system current time called to often?
        val now = System.currentTimeMillis()
        if (now > (lastTickMs + TICK_INTERVAL_MS)) {
            lastTickMs = now
            tickWireguard()
            ticks++

            if (ticks % ERRORS_RESET_AFTER_TICKS == 0) errorsRecently = 0
        }
    }

    private fun tickWireguard() {
        op.rewind()
        val destination = buffer
        destination.rewind()
        destination.limit(destination.capacity())
        val response = BoringTunJNI.wireguard_tick(boringtunHandle, destination, destination.capacity(), op)
        destination.limit(response)
        val opCode = op[0].toInt()
        when (opCode) {
            BoringTunJNI.WRITE_TO_NETWORK -> {
                forwardToGateway()
            }
            BoringTunJNI.WIREGUARD_ERROR -> {
                errorOccurred("tick: wireguard error: ${BoringTunJNI.errors[response]}".ex())
            }
            BoringTunJNI.WIREGUARD_DONE -> {
            }
            else -> {
                errorOccurred("tick: wireguard timer unknown response: $opCode".ex())
            }
        }
    }

    private fun errorOccurred(ex: BlokadaException) {
        log.e("Packet loop error (${++errorsRecently}): ${ex.message}")
        if (errorsRecently >= MAX_ERRORS) {
            errorsRecently = 0
            throw BlokadaException("Too many errors recently", ex)
        }
    }

    private fun shouldInterruptLoop() = (isInterrupted || this.errorPipe == null)

    private fun cleanup() {
        log.v("Cleaning up resources: $this")
        closeGatewaySocket()
        try { Os.close(errorPipe) } catch (ex: Exception) {}
        errorPipe = null

        // This is managed by the SystemTunnel
//        try { Os.close(devicePipe) } catch (ex: Exception) {}
//        devicePipe = null
    }

    private var purgeCount = 0
    private fun purge() {
        if (++purgeCount % 1024 == 0) {
            try {
                val l = PacketFactoryPropertiesLoader.getInstance()
                val field = l.javaClass.getDeclaredField("loader")
                field.isAccessible = true
                val loader = field.get(l) as PropertiesLoader
                loader.clearCache()
            } catch (e: Exception) {}
        }
    }

}
