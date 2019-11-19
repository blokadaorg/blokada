package core

data class TunnelPause(
        val vpn: Boolean = false,
        val adblocking: Boolean = false,
        val dns: Boolean = false
)

class TunnelPausePersistence {
    val load = { ->
        Result.of { Persistence.paper().read<TunnelPause>("tunnel:pause", TunnelPause()) }
    }
    val save = { pause: TunnelPause ->
        Result.of { Persistence.paper().write("tunnel:pause", pause) }
    }
}
