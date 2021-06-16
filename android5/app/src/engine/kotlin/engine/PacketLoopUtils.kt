/*
 * This file is part of Blokada.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Copyright © 2021 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package engine

import android.os.ParcelFileDescriptor
import android.system.Os
import android.system.OsConstants
import android.system.StructPollfd
import org.pcap4j.packet.IpPacket
import org.pcap4j.packet.Packet
import service.LogService
import service.PrintsDebugInfo
import utils.Logger
import java.net.DatagramSocket
import java.nio.ByteBuffer
import java.util.*
import kotlin.experimental.and

internal class Forwarder(private val ttl: Long = 10 * 1000): PrintsDebugInfo {

    private val log = Logger("PLForwarder")
    private val store = LinkedList<ForwardRule>()

    init {
        LogService.onShareLog("PLForwarder", this)
    }

    fun add(socket: DatagramSocket, originEnvelope: Packet) {
        if (size() >= 1024) {
            log.w("Forwarder reached 1024 open sockets, closing oldest")
            close(0)
        }

        // Close all old sockets
        var counter = 0
        while (size() > 0 && get(0).isOld()) {
            close(0)
            counter++
        }

        if (counter > 0) log.v("Forwarder closed $counter old sockets")

        val fd = ParcelFileDescriptor.fromDatagramSocket(socket)
        val pipe = StructPollfd()
        pipe.fd = fd.fileDescriptor
        pipe.listenFor(OsConstants.POLLIN)

        store.add(ForwardRule(socket, originEnvelope, pipe, fd, ttl))
    }

    fun close(index: Int) {
        val rule = store.removeAt(index)
        closeRule(rule)
    }

    operator fun get(index: Int) = store[index]

    fun size() = store.size

    private fun closeRule(rule: ForwardRule) {
        // Never sure enough which one to close
        try { rule.fd.close() } catch (ex: Exception) {}
        try { rule.socket.close() } catch (ex: Exception) {}
        try { Os.close(rule.pipe.fd) } catch (ex: Exception) {}
    }

    fun closeAll() {
        var counter = 0
        while (size() > 0) {
            close(0)
            counter++
        }
        log.v("Forwarder closed all remaining sockets: $counter")
    }

    override fun printDebugInfo() {
        log.v("${size()} sockets waiting")
        var i = 0
        while (i < size()) {
            val rule = get(i++)
            log.v("%s %s".format((rule.originEnvelope.header as? IpPacket.IpHeader)?.dstAddr, rule.added))
        }
    }

}

internal data class ForwardRule(
    val socket: DatagramSocket,
    val originEnvelope: Packet,
    val pipe: StructPollfd,
    val fd: ParcelFileDescriptor,
    val ttl: Long
) {
    val added = System.currentTimeMillis()

    fun isOld(): Boolean {
        return (System.currentTimeMillis() - added) > ttl
    }
}

internal fun StructPollfd.listenFor(events: Int) {
    this.events = events.toShort()
}

internal fun StructPollfd.isEvent(event: Int): Boolean {
    return this.revents.toInt() and event != 0
}

internal fun dstAddress4(packet: ByteArray, length: Int, ip: ByteArray): Boolean {
    return (
            (packet[16] and ip[0]) == ip[0] &&
                    (packet[17] and ip[1]) == ip[1] &&
                    (packet[18] and ip[2]) == ip[2]
            )
}

internal fun srcAddress4(packet: ByteBuffer, ip: ByteArray): Boolean {
    return (
            (packet[12] and ip[0]) == ip[0] &&
                    (packet[13] and ip[1]) == ip[1] &&
                    (packet[14] and ip[2]) == ip[2] &&
                    (packet[15] and ip[3]) == ip[3]
            )
}

internal fun isUdp(packet: ByteBuffer): Boolean {
    return packet[9] == 17.toByte()
}

internal fun isUdp(packet: ByteArray): Boolean {
    return packet[9] == 17.toByte()
}

