package org.blokada.property

import gs.environment.Identity
import org.obsolete.IProperty
import java.io.File
import java.net.InetAddress
import java.net.URL
import java.util.*

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
    abstract val tunnelAdsCount: IProperty<Int>
    abstract val tunnelRecentAds: IProperty<List<String>>

    abstract val repo: IProperty<Repo>
    abstract val localised: IProperty<Localised>

    abstract val apps: IProperty<List<App>>

    // Those do not change during lifetime of the app
    abstract val filterConfig: IProperty<FilterConfig>
    abstract val tunnelConfig: IProperty<TunnelConfig>
    abstract val repoConfig: IProperty<RepoConfig>
    abstract val versionConfig: IProperty<VersionConfig>
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

data class Repo(
        val contentPath: URL?,
        val locales: List<Locale>,
        val pages: Map<Locale, Pair<URL, URL>>,
        val newestVersionCode: Int,
        val newestVersionName: String,
        val downloadLinks: List<URL>,
        val lastRefreshMillis: Long
)

data class Localised(
        val content: URL,
        val lastRefreshMillis: Long
        // TODO: filters too?
)

data class FilterConfig(
        val cacheFile: File,
        val exportFile: File,
        val cacheTTLMillis: Long,
        val repoURL: URL,
        val fetchTimeoutMillis: Int
)

data class TunnelConfig(
        val defaultEngine: String
)

data class RepoConfig(
        val cacheFile: File,
        val cacheTTLMillis: Long,
        val repoURL: URL,
        val fetchTimeoutMillis: Int,
        val notificationCooldownMillis: Long
)

data class VersionConfig(
        val appName: String,
        val appVersion: String,
        val appVersionCode: Int,
        val coreVersion: String,
        val uiVersion: String? = null
)
