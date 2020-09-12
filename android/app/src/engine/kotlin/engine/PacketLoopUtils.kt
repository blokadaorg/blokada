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
import android.system.Os
import android.system.OsConstants
import android.system.StructPollfd
import org.pcap4j.packet.Packet
import utils.Logger
import java.net.DatagramSocket
import java.nio.ByteBuffer
import java.util.*
import kotlin.experimental.and

internal class Forwarder(private val ttl: Long = 10 * 1000): Iterable<ForwardRule> {

    private val log = Logger("PLForwarder")
    private val store = LinkedList<ForwardRule>()

    fun add(socket: DatagramSocket, originEnvelope: Packet) {
        if (store.size >= 1024) {
            log.w("Forwarder reached 1024 open sockets")
            closeRule(store.element())
            store.remove()
        }
        while (store.isNotEmpty() && store.element().isOld()) {
            closeRule(store.element())
            store.remove()
        }

        val fd = ParcelFileDescriptor.fromDatagramSocket(socket)
        val pipe = StructPollfd()
        pipe.fd = fd.fileDescriptor
        pipe.listenFor(OsConstants.POLLIN)

        store.add(ForwardRule(socket, originEnvelope, pipe, fd, ttl))
    }

    override fun iterator() = store.iterator()
    operator fun get(index: Int) = store[index]
    fun size() = store.size

    fun closeRule(rule: ForwardRule) {
        // Never sure enough which one to close
        try { rule.fd.close() } catch (ex: Exception) {}
        try { rule.socket.close() } catch (ex: Exception) {}
        try { Os.close(rule.pipe.fd) } catch (ex: Exception) {}
    }

    fun closeAll() {
        log.v("Closing all remaining sockets in Forwarder")
        for(rule in store) {
            closeRule(rule)
        }
        store.clear()
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

