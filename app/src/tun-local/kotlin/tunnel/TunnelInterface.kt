package tunnel

import java.io.FileDescriptor

interface Tunnel {
    fun run(tunnel: FileDescriptor)
    fun runWithRetry(tunnel: FileDescriptor)
    fun stop()
}
