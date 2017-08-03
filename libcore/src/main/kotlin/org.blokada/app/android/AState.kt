package org.blokada.app.android

import android.content.Context
import android.os.Build
import android.os.PowerManager
import com.github.salomonbrys.kodein.instance
import org.blokada.app.*
import org.blokada.framework.*
import org.blokada.framework.android.*
import java.io.InputStreamReader
import java.net.URL
import java.nio.charset.Charset
import java.util.*
import java.util.Properties

/**
 * of Trance
 */
class AState(
        private val ctx: Context,
        private val kctx: KContext
) : State() {

    override val filterConfig = newProperty<FilterConfig>(kctx, { ctx.di().instance() })
    override val tunnelConfig = newProperty<TunnelConfig>(kctx, { ctx.di().instance() })
    override val repoConfig = newProperty<RepoConfig>(kctx, { ctx.di().instance() })
    override val versionConfig = newProperty<VersionConfig>(kctx, { ctx.di().instance() })

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

    override val startOnBoot  = newPersistedProperty(kctx, APrefsPersistence(ctx, "startOnBoot"),
            { true }
    )

    override val keepAlive = newPersistedProperty(kctx, APrefsPersistence(ctx, "keepAlive"),
            { false }
    )

    override val identity = newPersistedProperty(kctx, AIdentityPersistence(ctx), { identityFrom("") })

    override val connection = newProperty(kctx, {
        val watchdog: IWatchdog = ctx.di().instance()
        Connection(
            connected = isConnected(ctx) or watchdog.test(),
            tethering = isTethering(ctx),
            dnsServers = getDnsServers(ctx)
    ) })

    override val screenOn = newProperty(kctx, {
        val pm: PowerManager = ctx.di().instance()
        if (Build.VERSION.SDK_INT >= 20) { pm.isInteractive } else { pm.isScreenOn }
    })

    override val watchdogOn = newPersistedProperty(kctx, APrefsPersistence(ctx, "watchdogOn"),
            { true }
    )

    private val filtersRefresh = { it: List<Filter> ->
        val c = filterConfig()
        val serialiser: FilterSerializer = ctx.di().instance()
        val builtinFilters = try {
            serialiser.deserialise(load({ openUrl(c.repoURL, c.fetchTimeoutMillis) }))
        } catch (e: Exception) {
            // We may make this request exactly while establishing VPN, erroring out. Simply wait a bit.
            Thread.sleep(3000)
            serialiser.deserialise(load({ openUrl(c.repoURL, c.fetchTimeoutMillis) }))
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
        prop.load(InputStreamReader(openUrl(URL("${localised().content}/strings_filters.properties"),
                c.fetchTimeoutMillis), Charset.forName("UTF-8")))
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
                val now = ctx.di().instance<IEnvironment>().now()
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
                val selectedBlacklist = selected.filter{ !it.whitelist }
                val selectedWhitelist = selected.filter(Filter::whitelist)

                // Report counts as events
                val j = ctx.di().instance<IJournal>()
                val blacklistCount = selectedBlacklist.map { it.hosts.size }.sum()
                val whitelistCount = selectedWhitelist.map { it.hosts.size }.sum()
                j.event(Events.COUNT_BLACKLIST_HOSTS(blacklistCount))
                j.event(Events.COUNT_WHITELIST_HOSTS(whitelistCount))

                combine(selectedBlacklist, selectedWhitelist)
            },
            shouldRefresh = {
                val c = filterConfig()
                val now = ctx.di().instance<IEnvironment>().now()
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
        ctx.di().instance()
    })

    override val tunnelActiveEngine = newPersistedProperty(kctx, APrefsPersistence(ctx, "tunnelActiveEngine"),
            { tunnelConfig().defaultEngine }
    )

    override val tunnelAdsCount = newPersistedProperty(kctx, APrefsPersistence(ctx, "tunnelAdsCount"),
            { 0 }
    )

    override val tunnelRecentAds = newProperty<List<String>>(kctx, { listOf() })

    private val repoRefresh = {
        val j = ctx.di().instance<IJournal>()
        val now = ctx.di().instance<IEnvironment>().now()
        val repoURL = repoConfig().repoURL
        val fetchTimeout = repoConfig().fetchTimeoutMillis

        try {
            j.event(Events.UPDATE_CHECK_START)
            val repo = load({ openUrl(repoURL, fetchTimeout) })
            val locales = repo[1].split(" ").map { Locale(it) }
            val x = 2 + 2 * locales.size
            val pages = repo.subList(2, x).asSequence().batch(2).mapIndexed { i, l ->
                locales[i] to (URL(l[0]) to URL(l[1]))
            }.toMap()

            Repo(
                    contentPath = URL(repo[0]),
                    locales = locales,
                    pages = pages,
                    newestVersionCode = repo[x].toInt(),
                    newestVersionName = repo[x + 1],
                    downloadLinks = repo.subList(x + 2, repo.size).map { URL(it) },
                    lastRefreshMillis = now
            )
        } catch (e: Exception) {
            j.event(Events.UPDATE_CHECK_FAIL)
            throw e
        }
    }

    override val repo = newPersistedProperty(kctx, ARepoPersistence(ctx,
            default = repoRefresh ),
            zeroValue = { Repo(
                    contentPath = null,
                    locales = emptyList(),
                    pages = emptyMap(),
                    newestVersionCode = 0,
                    newestVersionName = "",
                    downloadLinks = emptyList(),
                    lastRefreshMillis = 0L
            ) },
            refresh = { repoRefresh() },
            shouldRefresh = {
                val now = ctx.di().instance<IEnvironment>().now()
                val ttl = repoConfig().cacheTTLMillis

                when {
                    it.lastRefreshMillis + ttl < now -> true
                    it.downloadLinks.isEmpty() -> true
                    it.contentPath == null -> true
                    it.locales.isEmpty() -> true
                    else -> false
                }
            }
    )

    private val localisedRefresh = {
        val now = ctx.di().instance<IEnvironment>().now()
        val preferred = getPreferredLocales()
        val available = repo().locales

        /**
         * Since pulling in proper locale lookup would take a lot of code dependencies, for now
         * I coded up something dead simple. If no exact match is found amoung available locales,
         * try matching just the language tag. This isn't a nice approach, but since we will support
         * only the main languages for a long time to come, it should do the job.
         */
        val exact = preferred.firstOrNull { available.contains(it) }
        val tag = if (exact == null) {
            val langs = preferred.map { it.language }.distinct()
            val lang = langs.firstOrNull { available.map { it.language }.contains(it) }
            lang ?: "en"
        } else exact.toString()
        val locale = Locale(tag)

        val content = URL("${repo().contentPath}/$tag")

        val changelog = try {
            val prop = Properties()
            prop.load(InputStreamReader(openUrl(URL("${content}/strings_repo.properties"),
                    repoConfig().fetchTimeoutMillis), Charset.forName("UTF-8")))
            prop.getProperty("b_changelog")
        } catch (e: Exception) {
            ""
        }

        Localised(
                content = content,
                feedback = repo().pages.get(locale)?.first ?: URL("${content}/help.html"),
                bug = repo().pages.get(locale)?.second ?: URL("${content}/help.html"),
                changelog = changelog,
                lastRefreshMillis = now
        )
    }

    override val localised = newPersistedProperty(kctx, ALocalisedPersistence(ctx,
            default = localisedRefresh ),
            zeroValue = { Localised(
                    content = URL("http://blokada.org/content/en"),
                    feedback = URL("http://localhost/feedback"),
                    bug = URL("http://localhost/bug"),
                    changelog = "",
                    lastRefreshMillis = 0L
            ) },
            refresh = { localisedRefresh() },
            shouldRefresh = {
                val now = ctx.di().instance<IEnvironment>().now()
                val ttl = repoConfig().cacheTTLMillis

                when {
                    it.lastRefreshMillis + ttl < now -> true
                    else -> false
                }
            }
    )

}

