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
import java.util.*
import javax.net.ssl.SSLSocket

internal class Forwarder(val ttl: Time = 10 * 1000) : Iterable<ForwardRule> {

    private val inUseConnections = LinkedList<ForwardRule>()
    private val availableConnections = LinkedList<ForwardRule>()

    fun add(socket: DatagramSocket, originEnvelope: Packet) {
        cleanupConnectionList(inUseConnections)
        inUseConnections.add(ForwardRuleDatagram(socket, originEnvelope, ttl))
    }

    fun add(socket: SSLSocket, originEnvelope: Packet) {
        cleanupConnectionList(inUseConnections)
        inUseConnections.add(ForwardRuleTcp(socket, originEnvelope, ttl))
    }

    fun addAvailableConnection(rule: ForwardRule) {
        availableConnections.add(rule)
    }

    fun getAvailableConnection() : Closeable? {
        cleanupConnectionList(availableConnections)
        return if (availableConnections.isNotEmpty()) availableConnections.remove().socket() else null
    }

    private fun cleanupConnectionList(list: LinkedList<ForwardRule>) {
        if (list.size >= 1024) {
            w("forwarder reached 1024 open sockets")
            Result.of { list.element().socket().close() }
            list.remove()
        }
        while (list.isNotEmpty() && list.element().isOld()) {
            Result.of { list.element().socket().close() }
            list.remove()
        }
    }

    override fun iterator() = inUseConnections.iterator()

    fun size() = inUseConnections.size
}

internal abstract class ForwardRule(
        private val socket: Closeable,
        private val originEnvelope: Packet,
        private val ttl: Time
) {
    val added = System.currentTimeMillis()
    private var fileDescriptor : FileDescriptor? = null

    fun socket(): Closeable { return socket }

    fun originEnvelope(): Packet { return originEnvelope }

    fun isOld(): Boolean {
        return (System.currentTimeMillis() - added) > ttl
    }

    fun getFd(): FileDescriptor {
        fileDescriptor = fileDescriptor ?: getFdFromSocket()
        return fileDescriptor!!
    }

    abstract fun getFdFromSocket() : FileDescriptor

    abstract fun receive(packet: DatagramPacket)
}

internal class ForwardRuleDatagram(
        private val socket: DatagramSocket,
        originEnvelope: Packet,
        ttl: Time
): ForwardRule(socket, originEnvelope, ttl) {

    override fun getFdFromSocket(): FileDescriptor {
        return ParcelFileDescriptor.fromDatagramSocket(socket).fileDescriptor
    }
    override fun receive(packet: DatagramPacket) {
        socket.receive(packet)
    }
}

internal class ForwardRuleTcp(
        private val socket: Socket,
        originEnvelope: Packet,
        ttl: Time
): ForwardRule(socket, originEnvelope, ttl) {

    override fun getFdFromSocket(): FileDescriptor {
        return ParcelFileDescriptor.fromSocket(socket).fileDescriptor
    }
    override fun receive(packet: DatagramPacket) {

        val inputStream = DataInputStream(socket.inputStream)
        //read TCP response
        val length = inputStream.readUnsignedShort()
        inputStream.read(packet.data)
        packet.setData(packet.data, 0, length)
    }
}
