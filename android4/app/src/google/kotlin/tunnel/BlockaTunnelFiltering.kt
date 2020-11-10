package tunnel

import java.net.InetSocketAddress
import java.nio.ByteBuffer

internal class BlockaTunnelFiltering(
        private val dnsServers: List<InetSocketAddress>,
        private val blockade: Blockade,
        private val loopback: () -> Any,
        private val errorOccurred: (String) -> Any,
        private val buffer: ByteBuffer
) {
    fun handleFromDevice(fromDevice: ByteArray, length: Int) = false

    fun handleToDevice(destination: ByteBuffer, length: Int) = false

    fun restart() {}
}
