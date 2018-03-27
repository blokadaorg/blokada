/* Copyright (C) 2017 Karsen Gauss <a@kar.gs>
 *
 * Derived from DNS66:
 * Copyright (C) 2016 Julian Andres Klode <jak@jak-linux.org>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3.
 *
 * Contributions shall also be provided under any later versions of the
 * GPL.
 */
package adblocker

import android.os.ParcelFileDescriptor
import android.system.ErrnoException
import android.system.Os
import android.system.OsConstants
import android.system.StructPollfd
import core.Dns
import core.Filters
import gs.environment.Journal
import org.pcap4j.packet.IpPacket
import org.pcap4j.packet.factory.PacketFactoryPropertiesLoader
import org.pcap4j.util.PropertiesLoader
import tunnel.ITunnelActions
import java.io.FileDescriptor
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.IOException
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.util.*

@android.annotation.TargetApi(21)
class TunnelThreadLollipopAndroid(
        val actions: ITunnelActions,
        val j: Journal,
        val s: Dns,
        val f: Filters,
        val adBlocked: (String) -> Unit,
        val error: (String) -> Unit
) : Runnable {

    private val thread = Thread(this, "TunnelThreadLollipopAndroid")
    private val loopbackQueue: Queue<ByteArray> = LinkedList()
    private val forwardQueue = ForwardQueue()

    private var blockFd: FileDescriptor? = null
    private var interruptFd: FileDescriptor? = null

    private val proxy = DnsProxy(s, f, object : IProxyEvents {

        override fun forward(packet: DatagramPacket, request: IpPacket?) {
            var dnsSocket: DatagramSocket? = null
            try {
                dnsSocket = DatagramSocket()
                actions.protect(dnsSocket)
                dnsSocket.send(packet)
                if (request != null) forwardQueue.add(Item(dnsSocket, request))
                else {
                    try {
                        dnsSocket.close()
                    } catch (e: Exception) {
                    }
                    dnsSocket = null
                }
            } catch (e: IOException) {
                j.log("forward error", e)
                try {
                    dnsSocket?.close()
                } catch (e: Exception) {
                }
                if (e.cause is ErrnoException) {
                    val errnoExc = e.cause as ErrnoException
                    if (errnoExc.errno == OsConstants.EPERM) {
                        throw Exception("EPERM")
                    }
                }
                return
            }
        }

        override fun loopback(packet: IpPacket) {
            loopbackQueue.add(packet.rawData)
        }

    }, adBlocked)

    init {
        // Init has to be below the proxy property initialisation, otherwise NPE. nice.
        thread.start()
    }

    fun stopThread() {
        proxy.stop()
        thread.interrupt()
        if (interruptFd != null) try { Os.close(interruptFd) } catch (e: ErrnoException) {}
        interruptFd = null
        try {
            thread.join(2000)
        } catch (e: InterruptedException) { }
    }

    override fun run() {
        var retry = 5
        while (true) {
            var connectTimeMillis = 0L
            try {
                connectTimeMillis = System.currentTimeMillis()
                loopTunnel()
                break
            } catch (e: InterruptedException) { break
            } catch (e: Exception) { /* retry below */ }

            // todo refactor retry logic
            if (System.currentTimeMillis() - connectTimeMillis >= 60 * 1000) retry = 5

            try {
                Thread.sleep(retry * 1000L)
            } catch (e: InterruptedException) { break }

            if (retry < 2 * 60) retry *= 2
        }
    }

    fun loopTunnel() {
        val packet = ByteArray(32767)

        val pipes = Os.pipe()
        interruptFd = pipes[0]
        blockFd = pipes[1]

        try {
            val fd = actions.fd()!!
            val inputStream = FileInputStream(fd)
            val outFd = FileOutputStream(fd)
            while (step(inputStream, outFd, packet)) {}
        } catch (e: Exception) {
            error(e.message ?: "unknown")
        } finally {
            if (blockFd != null) try { Os.close(blockFd) } catch (e: ErrnoException) {}
            blockFd = null
            throw Exception("loopTunnel failed")
        }
    }

    private fun StructPollfd.setEvents(events: Int) {
        this.events = events.toShort()
    }

    private fun StructPollfd.eventHappened(event: Int): Boolean {
        return this.revents.toInt() and event != 0
    }

    private fun step(input: FileInputStream, output: FileOutputStream, packet: ByteArray): Boolean {
        val deviceFd = StructPollfd()
        deviceFd.fd = input.fd
        if (loopbackQueue.isEmpty()) deviceFd.setEvents(OsConstants.POLLIN)
        else deviceFd.setEvents(OsConstants.POLLIN or OsConstants.POLLOUT)

        val blockFd = StructPollfd()
        blockFd.fd = this.blockFd
        blockFd.setEvents(OsConstants.POLLHUP or OsConstants.POLLERR)

        var i = -1
        val polls = arrayOfNulls<StructPollfd>(2 + forwardQueue.size())
        polls[0] = deviceFd
        polls[1] = blockFd
        for (item in forwardQueue) {
            i++
            val p = StructPollfd()
            p.fd = ParcelFileDescriptor.fromDatagramSocket(item.socket).fileDescriptor
            p.setEvents(OsConstants.POLLIN)
            polls[2 + i] = p
        }

        var result: Int
        while (true) {
            if (Thread.interrupted()) throw InterruptedException()
            try {
                result = Os.poll(polls as Array<StructPollfd>, -1)
                break
            } catch (e: ErrnoException) {
                if (e.errno == OsConstants.EINTR) continue
                throw e
            }
        }
        if (result == 0) return true

        if (blockFd.revents.toInt() != 0) return false

        i = -1
        val iterator = forwardQueue.iterator()
        while (iterator.hasNext()) {
            i++
            val item = iterator.next()
            if (polls[i + 2].eventHappened(OsConstants.POLLIN)) {
                iterator.remove()
                val datagram = ByteArray(1024)
                val replyPacket = DatagramPacket(datagram, datagram.size)
                item.socket.receive(replyPacket)
                proxy.handleResponse(item.packet, datagram)
                item.socket.close()
            }
        }

        if (deviceFd.eventHappened(OsConstants.POLLOUT))
            output.write(loopbackQueue.poll())
        if (deviceFd.eventHappened(OsConstants.POLLIN)) {
            val length = input.read(packet)
            if (length > 0) {
                // TODO: nocopy
                val readPacket = Arrays.copyOfRange(packet, 0, length)
                proxy.handleRequest(readPacket)
            }
        }

        clearCache()
        return true
    }

    private var count = 0
    private fun clearCache() {
        // prevent pcap4j leak.
        if (++count % 1024 == 0) {
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
