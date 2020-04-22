package tunnel

import android.system.ErrnoException
import android.system.Os
import android.system.OsConstants
import android.system.StructPollfd
import com.github.michaelbull.result.mapError
import com.github.michaelbull.result.onFailure
import core.*
import org.pcap4j.packet.factory.PacketFactoryPropertiesLoader
import org.pcap4j.util.PropertiesLoader
import java.io.*
import java.net.DatagramPacket
import java.util.*
import kotlin.math.min


internal class DnsTunnel(
        private var proxy: Proxy,
        private val powersave: Boolean,
        private val forwarder: Forwarder = Forwarder(),
        private val loopback: Queue<Triple<ByteArray, Int, Int>> = LinkedList()
) : Tunnel {

    private var device: FileDescriptor? = null
    private var error: FileDescriptor? = null

    private var cooldownCounter = 1
    private var epermCounter = 0

    private var packetBuffer = ByteArray(32767)
    private var datagramBuffer = ByteArray(1024)

    override fun run(tunnel: FileDescriptor) {
        v("running tunnel thread", this)

        val input = FileInputStream(tunnel)
        val output = FileOutputStream(tunnel)

        try {
            val errors = setupErrorsPipe()
            val device = setupDevicePipe(input)

            while (true) {
                if (threadInterrupted()) throw InterruptedException()

                if (loopback.isNotEmpty()) {
                    device.listenFor(OsConstants.POLLIN or OsConstants.POLLOUT)
                } else device.listenFor(OsConstants.POLLIN)

                val polls = setupPolls(errors, device)
                poll(polls)
                fromOpenSocketsToProxy(polls)
                fromLoopbackToDevice(device, output)
                fromDeviceToProxy(device, input, packetBuffer)
                cleanup()
                cooldownCounter = 1
            }
        } catch (ex: InterruptedException) {
            v("tunnel thread interrupted", this, ex.toString())
            Thread.currentThread().interrupt()
            throw ex
        } catch (ex: Exception) {
            val cause = ex.cause
            if (cause is ErrnoException && cause.errno == OsConstants.EPERM) {
                if (++epermCounter >= 3 && powersave) {
                    emit(TunnelEvents.TUNNEL_POWER_SAVING)
                    epermCounter = 0
                }
            } else {
                epermCounter = 0
                e("failed tunnel thread", this, ex)
            }
            throw ex
        } finally {
            v("cleaning up resources", this)
            Result.of { Os.close(error) }
            Result.of { input.close() }
            Result.of { output.close() }
        }
    }

    override fun runWithRetry(tunnel: FileDescriptor) {
        var interrupted = false
        do {
            Result.of { run(tunnel) }.mapError {
                if (it is InterruptedException || threadInterrupted()) interrupted = true
                else {
                    val cooldown = min(cooldownTtl * cooldownCounter, cooldownMax)
                    cooldownCounter *= 2
                    e("tunnel thread error, will restart after $cooldown ms", this, it.toString())
                    Result.of { Thread.sleep(cooldown) }.mapError {
                        if (it is InterruptedException || threadInterrupted()) interrupted = true
                    }
                }
            }
        } while (!interrupted)
        v("tunnel thread shutdown", this)
    }

    override fun stop() {
        v("stopping poll, if any")
        Result.of { Os.close(error) }
        error = null
    }

    private fun setupErrorsPipe() = {
        val pipe = Os.pipe()
        error = pipe[0]
        val errors = StructPollfd()
        errors.fd = error
        errors.listenFor(OsConstants.POLLHUP or OsConstants.POLLERR)
        errors
    }()

    private fun setupDevicePipe(input: FileInputStream) = {
        this.device = input.fd
        val device = StructPollfd()
        device.fd = input.fd
        device
    }()

    private fun setupPolls(errors: StructPollfd, device: StructPollfd) = {
        val polls = arrayOfNulls<StructPollfd>(2 + forwarder.size()) as Array<StructPollfd>
        polls[0] = errors
        polls[1] = device

        for ((i, rule) in forwarder.withIndex()) {
            val p = StructPollfd()
            p.fd = rule.getFd()
            p.listenFor(OsConstants.POLLIN)
            polls[2 + i] = p
        }
        polls
    }()

    private fun poll(polls: Array<StructPollfd>) {
        while (true) {
            try {
                val result = Os.poll(polls, -1)
                if (result == 0) return
                if (polls[0].revents.toInt() != 0) throw InterruptedException("poll interrupted")
                break
            } catch (e: ErrnoException) {
                if (e.errno == OsConstants.EINTR) continue
                throw e
            }
        }
    }

    private fun fromOpenSocketsToProxy(polls: Array<StructPollfd>) {
        var index = 0
        val iterator = forwarder.iterator()
        while (iterator.hasNext()) {
            val rule = iterator.next()
            if (polls[2 + index++].isEvent(OsConstants.POLLIN)) {
                iterator.remove()
                val responsePacket = DatagramPacket(datagramBuffer, datagramBuffer.size)
                Result.of {
                    rule.receive(responsePacket)
                    proxy.toDevice( datagramBuffer, responsePacket.length, rule.originEnvelope())
                }.onFailure { w("failed receiving socket", it) }
                forwarder.addAvailableConnection(rule)
            }
        }
    }

    private fun fromLoopbackToDevice(device: StructPollfd, output: OutputStream) {
        if (device.isEvent(OsConstants.POLLOUT)) {
            val (buffer, offset, length) = loopback.poll()
            output.write(buffer, offset, length)
        }
    }

    private fun fromDeviceToProxy(device: StructPollfd, input: InputStream,
                                  buffer: ByteArray) {
        if (device.isEvent(OsConstants.POLLIN)) {
            val length = input.read(buffer)
            if (length > 0) {
                // TODO: nocopy
                val readPacket = Arrays.copyOfRange(buffer, 0, length)
                proxy.fromDevice(readPacket, length)
            }
        }
    }

    private fun threadInterrupted() = (Thread.interrupted() || this.error == null)

    private var count = 0
    private fun cleanup() {
        if (++count % 1024 == 0) {
            try {
                val l = PacketFactoryPropertiesLoader.getInstance()
                val field = l.javaClass.getDeclaredField("loader")
                field.isAccessible = true
                val loader = field.get(l) as PropertiesLoader
                loader.clearCache()
            } catch (e: Exception) {
            }
        }
    }

}

private fun StructPollfd.listenFor(events: Int) {
    this.events = events.toShort()
}

private fun StructPollfd.isEvent(event: Int): Boolean {
    return this.revents.toInt() and event != 0
}


