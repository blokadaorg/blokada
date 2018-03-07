package org.blokada.property

import gs.environment.Identity
import org.obsolete.IProperty
import java.io.File
import java.net.InetAddress

abstract class State {
    abstract val enabled: IProperty<Boolean>
    abstract val active: IProperty<Boolean>
    abstract val restart: IProperty<Boolean>
    abstract val retries: IProperty<Int>
    abstract val firstRun: IProperty<Boolean>
    abstract val updating: IProperty<Boolean>
    abstract val obsolete: IProperty<Boolean>
    abstract val startOnBoot: IProperty<Boolean>
    abstract val keepAlive: IProperty<Boolean>
    abstract val identity: IProperty<Identity>

    abstract val connection: IProperty<Connection>
    abstract val screenOn: IProperty<Boolean>
    abstract val watchdogOn: IProperty<Boolean>

    abstract val filters: IProperty<List<Filter>>
    abstract val filtersCompiled: IProperty<Set<String>>

    abstract val tunnelState: IProperty<TunnelState>
    abstract val tunnelPermission: IProperty<Boolean>
    abstract val tunnelEngines: IProperty<List<Engine>>
    abstract val tunnelActiveEngine: IProperty<String>
    abstract val tunnelDropCount: IProperty<Int>
    abstract val tunnelRecentDropped: IProperty<List<String>>

    abstract val apps: IProperty<List<App>>

    // Those do not change during lifetime of the app
    abstract val filterConfig: IProperty<FilterConfig>
    abstract val tunnelConfig: IProperty<TunnelConfig>
}

data class Connection(
        val connected: Boolean,
        val tethering: Boolean = false,
        val dnsServers: List<InetAddress> = listOf()
) {
    fun isWaiting(): Boolean {
        return !connected || tethering
    }
}

data class Filter(
        val id: String,
        val source: IFilterSource,
        val credit: String? = null,
        var valid: Boolean = false,
        var active: Boolean = false,
        var whitelist: Boolean = false,
        var hosts: List<String> = emptyList(),
        var localised: LocalisedFilter? = null
) {

    override fun hashCode(): Int {
        return source.hashCode()
    }

    override fun equals(other: Any?): Boolean {
        if (other !is Filter) return false
        return source.equals(other.source)
    }
}

data class App(
        val appId: String,
        val label: String,
        val system: Boolean
)

data class LocalisedFilter(
        val name: String,
        val comment: String? = null
)

open class Engine (
        val id: String,
        val supported: Boolean = true,
        val recommended: Boolean = false,
        val createIEngineManager: (e: EngineEvents) -> IEngineManager
)

data class EngineEvents (
        val adBlocked: (String) -> Unit = {},
        val error: (String) -> Unit = {},
        val onRevoked: () -> Unit = {}
)

enum class TunnelState {
    INACTIVE, ACTIVATING, ACTIVE, DEACTIVATING, DEACTIVATED
}

data class FilterConfig(
        val cacheFile: File,
        val exportFile: File,
        val cacheTTLMillis: Long,
        val fetchTimeoutMillis: Int
)

data class TunnelConfig(
        val defaultEngine: String
)

