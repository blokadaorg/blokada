package core

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.PowerManager
import com.github.salomonbrys.kodein.instance
import filter.FilterSerializer
import gs.environment.*
import gs.obsolete.hasCompleted
import gs.property.isCacheValid
import gs.property.newPersistedProperty
import gs.property.newProperty
import org.obsolete.combine
import org.obsolete.downloadFilters
import tunnel.checkTunnelPermissions
import java.io.InputStreamReader
import java.nio.charset.Charset
import java.util.Properties

/**
 * of Trance
 */
class AState(
        private val kctx: Worker,
        private val xx: Environment,
        private val ctx: Context
) : State() {

    private val pages: Pages by xx.instance()

    override val filterConfig = newProperty<FilterConfig>(kctx, { ctx.inject().instance() })
    override val tunnelConfig = newProperty<TunnelConfig>(kctx, { ctx.inject().instance() })

    override val enabled = newPersistedProperty(kctx, APrefsPersistence(ctx, "enabled"),
            { false }
    )

    override val active = newPersistedProperty(kctx, APrefsPersistence(ctx, "active"),
            { false }
    )

    override val restart = newPersistedProperty(kctx, APrefsPersistence(ctx, "restart"),
            { false }
    )

    override val retries = newProperty(kctx, { 3 })

    override val firstRun = newPersistedProperty(kctx, APrefsPersistence(ctx, "firstRun"),
            { true }
    )

    override val updating = newProperty(kctx, { false })

    override val obsolete = newPersistedProperty(kctx, APrefsPersistence(ctx, "obsolete"),
            { false }
    )

    override val startOnBoot  = newPersistedProperty(kctx, APrefsPersistence(ctx, "startOnBoot"),
            { true }
    )

    override val keepAlive = newPersistedProperty(kctx, APrefsPersistence(ctx, "keepAlive"),
            { false }
    )

    override val identity = newPersistedProperty(kctx, AIdentityPersistence(ctx), { identityFrom("") })

    override val connection = newProperty(kctx, {
        val watchdog: IWatchdog = ctx.inject().instance()
        val dns: Dns = ctx.inject().instance()
        Connection(
                connected = isConnected(ctx) or watchdog.test(),
                tethering = isTethering(ctx),
                dnsServers = {
                    val d = dns.choices().firstOrNull { it.active }
                    if (d == null || d.servers.isEmpty()) getDnsServers(ctx)
                    else d.servers
                }()
        )
    })

    override val screenOn = newProperty(kctx, {
        val pm: PowerManager = ctx.inject().instance()
        pm.isInteractive
    })

    override val watchdogOn = newPersistedProperty(kctx, APrefsPersistence(ctx, "watchdogOn"),
            { true }
    )

    private val filtersRefresh = { it: List<Filter> ->
        val c = filterConfig()
        val serialiser: FilterSerializer = ctx.inject().instance()
        val builtinFilters = try {
            serialiser.deserialise(load({ openUrl(pages.filters(), c.fetchTimeoutMillis) }))
        } catch (e: Exception) {
            // We may make this request exactly while establishing VPN, erroring out. Simply wait a bit.
            Thread.sleep(3000)
            serialiser.deserialise(load({ openUrl(pages.filters(), c.fetchTimeoutMillis) }))
        }

        val newFilters = if (it.isEmpty()) {
            // First preselect
            builtinFilters
        } else {
            // Update existing filters just in case
            it.map { filter ->
                val newFilter = builtinFilters.find { it == filter }
                if (newFilter != null) {
                    newFilter.active = filter.active
                    newFilter.localised = filter.localised
                    newFilter
                } else filter
            }
        }

        // Try to fetch localised copy for filters if available
        val prop = Properties()
        prop.load(InputStreamReader(openUrl(pages.filtersStrings(), c.fetchTimeoutMillis), Charset.forName("UTF-8")))
        newFilters.forEach { try {
            it.localised = LocalisedFilter(
                    name = prop.getProperty("${it.id}_name")!!,
                    comment = prop.getProperty("${it.id}_comment")
            )
        } catch (e: Exception) {}}

        newFilters
    }

    override val filters = newPersistedProperty(kctx,
            persistence = AFiltersPersistence(ctx, { filtersRefresh(emptyList()) }),
            zeroValue = { emptyList() },
            refresh = filtersRefresh,
            shouldRefresh = {
                val c = filterConfig()
                val now = ctx.inject().instance<Time>().now()
                when {
                    !isCacheValid(c.cacheFile, c.cacheTTLMillis, now) -> true
                    it.isEmpty() -> true
                // TODO: maybe check if we have connectivity (assuming we can trust it)
                    else -> false
                }
            }
    )

    override val filtersCompiled = newPersistedProperty(kctx,
            persistence = ACompiledFiltersPersistence(ctx),
            zeroValue = { emptySet() },
            refresh = {
                val selected = filters().filter(Filter::active)
                downloadFilters(selected)
                val selectedBlacklist = selected.filter { !it.whitelist }
                val selectedWhitelist = selected.filter(Filter::whitelist)

                // Report counts as events
                val j = ctx.inject().instance<Journal>()
                val blacklistCount = selectedBlacklist.map { it.hosts.size }.sum()
                val whitelistCount = selectedWhitelist.map { it.hosts.size }.sum()
                j.event(Events.COUNT_BLACKLIST_HOSTS(blacklistCount))
                j.event(Events.COUNT_WHITELIST_HOSTS(whitelistCount))

                combine(selectedBlacklist, selectedWhitelist)
            },
            shouldRefresh = {
                val c = filterConfig()
                val now = ctx.inject().instance<Time>().now()
                when {
                    !isCacheValid(c.cacheFile, c.cacheTTLMillis, now) -> true
                    it.isEmpty() -> true
                    else -> false
                }
            }
    )

    override val tunnelState = newProperty(kctx, { TunnelState.INACTIVE })

    override val tunnelPermission = newProperty(kctx, {
        val (completed, _) = hasCompleted(null, { checkTunnelPermissions(ctx) })
        completed
    })

    override val tunnelEngines = newProperty<List<Engine>>(kctx, {
        ctx.inject().instance()
    })

    override val tunnelActiveEngine = newPersistedProperty(kctx, APrefsPersistence(ctx, "tunnelActiveEngine"),
            { tunnelConfig().defaultEngine }
    )

    override val tunnelDropCount = newPersistedProperty(kctx, APrefsPersistence(ctx, "tunnelDropCount"),
            { 0 }
    )

    override val tunnelRecentDropped = newProperty<List<String>>(kctx, { listOf() })

    private val appsRefresh = {
        val installed = ctx.packageManager.getInstalledApplications(PackageManager.GET_META_DATA)
        installed.map {
            App(
                    appId = it.packageName,
                    label = ctx.packageManager.getApplicationLabel(it).toString(),
                    system = (it.flags and ApplicationInfo.FLAG_SYSTEM) != 0
            )
        }.sortedBy { it.label }
    }

    override val apps = newProperty(kctx, zeroValue = { appsRefresh() }, refresh = { appsRefresh() })
}

