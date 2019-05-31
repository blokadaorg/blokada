package tunnel

import android.os.ParcelFileDescriptor
import android.system.ErrnoException
import android.system.Os
import android.system.OsConstants
import android.system.StructPollfd
import com.github.michaelbull.result.mapError
import core.Kontext
import core.Result
import org.pcap4j.packet.factory.PacketFactoryPropertiesLoader
import org.pcap4j.util.PropertiesLoader
import java.io.*
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.nio.ByteBuffer
import kotlin.math.min

class Buffers {
    companion object {
        val MTU = 1600
        val BUFFERS = 5
    }

    private val FREE = 0
    private val TAKEN = 1

    private val buffers = arrayOfNulls<ByteBuffer>(BUFFERS)
    private val bufferStatus = arrayOfNulls<Int>(BUFFERS)

    private var currentBuffer = 0

    init {
        for (i in 0 until BUFFERS) {
            buffers[i] = ByteBuffer.allocateDirect(MTU)
            bufferStatus[i] = FREE
        }
    }

    fun getFreeBuffer(): Int {
        if (bufferStatus[currentBuffer] == FREE) {
//            "buffer".ktx().e("XXX getting buffer $currentBuffer")
            bufferStatus[currentBuffer] = TAKEN
            val b = buffers[currentBuffer]!!
            b.limit(b.capacity())
            b.rewind()
            return currentBuffer
        }
        else {
            var takenBuffers = 1
            do {
                currentBuffer = (currentBuffer + 1) % BUFFERS
                if (bufferStatus[currentBuffer] == FREE) {
//                    "buffer".ktx().e("XXX getting buffer $currentBuffer")
                    bufferStatus[currentBuffer] = TAKEN
                    val b = buffers[currentBuffer]!!
                    b.rewind()
                    b.limit(b.capacity())
                    return currentBuffer
                }
                else if (takenBuffers++ == BUFFERS) throw Exception("no free buffers left")
            } while (true)
        }
    }

    operator fun get(index: Int): ByteBuffer {
        return buffers[index]!!
    }

    fun returnBuffer(bufferId: Int) {
//        "buffer".ktx().e("XXX returning buffer $bufferId", Exception())
        bufferStatus[bufferId] = FREE
    }

    fun returnAllBuffers() {
        bufferStatus.map { FREE }
    }
}

internal class BlockaTunnel(
        private var proxy: BlockaProxy,
        private val config: TunnelConfig,
        private val blockaConfig: BlockaConfig,
        private val buffers: Buffers,
        private val doCreateSocket: () -> DatagramSocket
): Tunnel {

    private var device: FileDescriptor? = null
    private var error: FileDescriptor? = null

    private var gatewaySocket: DatagramSocket? = null
    private var gatewayParcelFileDescriptor: ParcelFileDescriptor? = null

    private val cooldownTtl = 300L
    private val cooldownMax = 3000L
    private var cooldownCounter = 0
    private var epermCounter = 0

    private val loopbackBuffers = arrayOfNulls<ByteBuffer>(Buffers.BUFFERS)
    private val forwardBuffers = arrayOfNulls<ByteBuffer>(Buffers.BUFFERS)
    private val loopbackBuffersReverse = arrayOfNulls<Int>(Buffers.BUFFERS)
    private val forwardBuffersReverse = arrayOfNulls<Int>(Buffers.BUFFERS)

    private var currentLoopbackBuffer = 0
    private var currentForwardBuffer = 0
    private var lastLoopbackBuffer = 0
    private var lastForwardBuffer = 0

    private var loopbackQueued = false
    private var forwardQueued = false

    private val memory = ByteArray(Buffers.MTU)

    private val packet1 = DatagramPacket(memory, 0, 1)
    private val packet2 = DatagramPacket(memory, 0, 1)

    private var lastTickMs = 0L
    private val tickIntervalMs = 100

    fun openGatewaySocket(ktx: Kontext) {
        gatewayParcelFileDescriptor?.close()
        gatewaySocket?.close()
        gatewaySocket = doCreateSocket()
        gatewaySocket?.connect(InetAddress.getByName(blockaConfig.gatewayIp), blockaConfig.gatewayPort)
        ktx.v("connect to gateway ip: ${blockaConfig.gatewayIp}")

        proxy.forward = { ktx, bufferId ->
            val b = buffers[bufferId]
            packet1.setData(b.array(), b.arrayOffset() + b.position(), b.limit())

            Result.of {
                buffers.returnBuffer(bufferId)
                gatewaySocket!!.send(packet1)
            }.mapError { ex ->
                ktx.e("failed sending to gateway", ex.message ?: "", ex)
                throw ex
            }
        }

        proxy.loopback = { ktx, bufferId ->
            loopbackQueued = true
            loopbackBuffers[currentLoopbackBuffer] = buffers[bufferId]
            loopbackBuffersReverse[currentLoopbackBuffer] = bufferId
            lastLoopbackBuffer = currentLoopbackBuffer++
//            ktx.w("queued loopbacks: ${currentLoopbackBuffer}")
        }
    }

    override fun run(ktx: Kontext, tunnel: FileDescriptor) {
        ktx.v("running boring tunnel thread", this)

        val input = FileInputStream(tunnel)
        val output = FileOutputStream(tunnel)

        try {
            val errors = setupErrorsPipe()
            val device = setupDevicePipe(input)

            proxy.createTunnel(ktx)
            openGatewaySocket(ktx)

            val polls = setupPolls(ktx, errors, device)

            while (true) {
                if (threadInterrupted()) throw InterruptedException()

                if (loopbackQueued) {
                    device.listenFor(OsConstants.POLLIN or OsConstants.POLLOUT)
                } else device.listenFor(OsConstants.POLLIN)

                val gateway = polls[2]
                gateway.listenFor(OsConstants.POLLIN)

                poll(ktx, polls)
                tick(ktx)
                fromLoopbackToDevice(ktx, device, output)
                fromDeviceToProxy(ktx, device, input)
                fromGatewayToProxy(ktx, gateway)
                cleanup()
            }
        } catch (ex: InterruptedException) {
            ktx.v("tunnel thread interrupted", this, ex.toString())
            Thread.currentThread().interrupt()
            throw ex
        } catch (ex: Exception) {
            val cause = ex.cause
            if (cause is ErrnoException && cause.errno == OsConstants.EPERM) {
                if (++epermCounter >= 3 && config.powersave) {
                    ktx.emit(Events.TUNNEL_POWER_SAVING)
                    epermCounter = 0
                }
            } else {
                epermCounter = 0
                ktx.e("failed tunnel thread", this, ex)
            }
            throw ex
        } finally {
            ktx.v("cleaning up resources", this)
            buffers.returnAllBuffers()
            Result.of { Os.close(error) }
            Result.of { input.close() }
            Result.of { output.close() }
        }
    }

    override fun runWithRetry(ktx: Kontext, tunnel: FileDescriptor) {
        var interrupted = false
        do {
            Result.of { run(ktx, tunnel) }.mapError {
                if (it is InterruptedException || threadInterrupted()) interrupted = true
                else {
                    val cooldown = min(cooldownTtl * cooldownCounter++, cooldownMax)
                    ktx.e("tunnel thread error, will restart after $cooldown ms", this, it.toString())
                    Result.of { Thread.sleep(cooldown) }.mapError {
                        if (it is InterruptedException || threadInterrupted()) interrupted = true
                    }
                }
            }
        } while (!interrupted)
        ktx.v("tunnel thread shutdown", this)
    }

    override fun stop(ktx: Kontext) {
        Result.of { Os.close(error) }
        Result.of {
            ktx.v("closing gateway socket on stop")
            gatewayParcelFileDescriptor?.close()
            gatewaySocket?.close()
        }
        gatewayParcelFileDescriptor = null
        gatewaySocket = null
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

    private fun setupPolls(ktx: Kontext, errors: StructPollfd, device: StructPollfd) = {
        val polls = arrayOfNulls<StructPollfd>(3) as Array<StructPollfd>
        polls[0] = errors
        polls[1] = device

        val parcel = ParcelFileDescriptor.fromDatagramSocket(gatewaySocket)
        val gateway = StructPollfd()
        gateway.fd = parcel.fileDescriptor
        polls[2] = gateway
        gatewayParcelFileDescriptor = parcel

        polls
    }()

    private fun poll(ktx: Kontext, polls: Array<StructPollfd>) {
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

    private fun fromDeviceToProxy(ktx: Kontext, device: StructPollfd, input: InputStream) {
        if (device.isEvent(OsConstants.POLLIN)) {
            val length = input.read(memory, 0, Buffers.MTU)
            if (length > 0) {
                proxy.fromDevice(ktx, memory, length)
            }
        }
    }

    private fun fromGatewayToProxy(ktx: Kontext, gateway: StructPollfd) {
        if (gateway.isEvent(OsConstants.POLLIN)) {
//            ktx.v("from gateway to proxy")
            Result.of {
                packet1.setData(memory)
                gatewaySocket?.receive(packet1) ?: ktx.e("no socket")
                proxy.toDevice(ktx, memory, packet1.length)
            }.mapError { ex ->
                ktx.w("failed receiving from gateway", ex.message ?: "")
                val cause = ex.cause
                if (cause is ErrnoException && cause.errno == OsConstants.EBADF) throw ex
                else if (cause is ErrnoException && cause.errno == OsConstants.EPERM) throw ex
            }
        }
    }

    private fun fromLoopbackToDevice(ktx: Kontext, device: StructPollfd, output: OutputStream) {
        if (device.isEvent(OsConstants.POLLOUT)) {
//            ktx.v("from loopback to device")
            repeat(lastLoopbackBuffer + 1) {
                val b = loopbackBuffers[it]!!
                val id = loopbackBuffersReverse[it]!!
                buffers.returnBuffer(id)
                output.write(b.array(), b.arrayOffset() + b.position(), b.limit())
            }
            loopbackQueued = false
            currentLoopbackBuffer = 0
            lastLoopbackBuffer = 0
//            ktx.v("queued loopbacks: 0")
        }
    }


    private fun tick(ktx: Kontext) {
        // TODO: system current time called to often?
        val now = System.currentTimeMillis()
        if (now > (lastTickMs + tickIntervalMs)) {
            lastTickMs = now
            proxy.tick(ktx)
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


