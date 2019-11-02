package tunnel

import android.os.ParcelFileDescriptor
import core.Result
import core.Time
import core.w
import org.pcap4j.packet.Packet
import java.io.Closeable
import java.io.DataInputStream
import java.io.FileDescriptor
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.Socket
import java.nio.ByteBuffer
import java.util.*
import javax.net.ssl.SSLSocket

internal class Forwarder(val ttl: Time = 10 * 1000) : Iterable<ForwardRule> {

    private val store = LinkedList<ForwardRule>()

    fun add(socket: DatagramSocket, originEnvelope: Packet) {
        cleanupStore()
        store.add(ForwardRuleDatagram(socket, originEnvelope, ttl))
    }

    fun add(socket: SSLSocket, originEnvelope: Packet) {
        cleanupStore()
        store.add(ForwardRuleTcp(socket, originEnvelope, ttl))
    }

    private fun cleanupStore() {
        if (store.size >= 1024) {
            w("forwarder reached 1024 open sockets")
            Result.of { store.element().getCloseable().close() }
            store.remove()
        }
        while (store.isNotEmpty() && store.element().isOld()) {
            Result.of { store.element().getCloseable().close() }
            store.remove()
        }
    }

    override fun iterator() = store.iterator()

    fun size() = store.size
}

//TODO: cleanup class inheritance
internal abstract class ForwardRule {
    val added = System.currentTimeMillis()

    fun isOld(): Boolean {
        return (System.currentTimeMillis() - added) > ttl()
    }

    abstract fun getFd(): FileDescriptor

    abstract fun ttl(): Time

    abstract fun originEnvelope(): Packet

    abstract fun getCloseable(): Closeable

    abstract fun receive(packet: DatagramPacket)
}

internal class ForwardRuleDatagram(
        private val socket: DatagramSocket,
        private val originEnvelope: Packet,
        private val ttl: Time
): ForwardRule() {
    override fun getFd(): FileDescriptor {
        return ParcelFileDescriptor.fromDatagramSocket(socket).fileDescriptor
    }
    override fun ttl(): Time {
        return ttl
    }
    override fun originEnvelope(): Packet {
        return originEnvelope
    }
    override fun getCloseable(): Closeable {
        return socket
    }
    override fun receive(packet: DatagramPacket) {
        socket.receive(packet)
    }
}

internal class ForwardRuleTcp(
        private val socket: Socket,
        private val originEnvelope: Packet,
        private val ttl: Time
): ForwardRule() {
    override fun getFd(): FileDescriptor {
        return ParcelFileDescriptor.fromSocket(socket).fileDescriptor
    }
    override fun ttl(): Time {
        return ttl
    }
    override fun originEnvelope(): Packet {
        return originEnvelope
    }
    override fun getCloseable(): Closeable {
        return socket
    }
    override fun receive(packet: DatagramPacket) {

        DataInputStream(socket.inputStream).use {
            //read TCP response
            val length = it.readUnsignedShort()
            it.read(packet.data)
            packet.setData(packet.data, 0, length)
        }
    }
}
