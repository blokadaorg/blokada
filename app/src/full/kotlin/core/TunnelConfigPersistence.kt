package core

import tunnel.TunnelConfig

fun setTunnelPersistenceSource() {
    Register.sourceFor(
        TunnelConfig::class.java, default = TunnelConfig(),
        source = PaperSource("tunnel:config")
    )
}
