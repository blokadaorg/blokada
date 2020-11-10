package core

import tunnel.TunnelConfig

fun setTunnelPersistenceSource() {
    Register.sourceFor(TunnelConfig::class.java, default = TunnelConfig(adblocking = false),
            source = NoAdblockingSource())
}

private class NoAdblockingSource: PaperSource<TunnelConfig>("tunnel:config") {
    override fun <T> get(classOfT: Class<T>, id: String?): T? {
        val tun = super.get(classOfT, id) as TunnelConfig?
        return tun?.copy(adblocking = false) as T?
    }
}
