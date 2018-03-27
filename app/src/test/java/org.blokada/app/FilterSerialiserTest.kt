package org.blokada.app

import com.github.salomonbrys.kodein.Kodein
import com.github.salomonbrys.kodein.bind
import com.github.salomonbrys.kodein.instance
import com.github.salomonbrys.kodein.singleton
import core.*
import filter.FilterSerializer
import filter.FilterSourceSingle
import nl.komponents.kovenant.Kovenant
import nl.komponents.kovenant.testMode
import org.obsolete.KContext
import org.blokada.framework.*
import org.junit.Test
import org.junit.Assert.*
import java.io.File
import java.net.URL
import java.util.*

class FilterSerialiserTest {

    private fun newDeps(kctx: KContext): Kodein.Module {
        return Kodein.Module {
            bind<Filters>() with singleton {
                object : Filters() {
                    override val enabled = org.obsolete.newProperty(kctx, { false })
                    override val active = org.obsolete.newProperty(kctx, { false })
                    override val retries = org.obsolete.newProperty(kctx, { 3 })
                    override val restart = org.obsolete.newProperty(kctx, { false })
                    override val firstRun = org.obsolete.newProperty(kctx, { false })
                    override val updating = org.obsolete.newProperty(kctx, { false })
                    override val obsolete = org.obsolete.newProperty(kctx, { false })
                    override val startOnBoot = org.obsolete.newProperty(kctx, { false })
                    override val keepAlive = org.obsolete.newProperty(kctx, { false })
                    override val identity = org.obsolete.newProperty(kctx, { generateIdentity(IDENTITY_UUID) })
                    override val connection = org.obsolete.newProperty(kctx, { Connection(connected = true) })
                    override val watchdogOn = org.obsolete.newProperty(kctx, { false })
                    override val screenOn = org.obsolete.newProperty(kctx, { true })
                    override val filters = org.obsolete.newProperty(kctx, { listOf<Filter>() })
                    override val filtersCompiled = org.obsolete.newProperty(kctx, { setOf<String>() })
                    override val tunnelState = org.obsolete.newProperty(kctx, { TunnelState.INACTIVE })
                    override val tunnelPermission = org.obsolete.newProperty(kctx, { false })
                    override val tunnelEngines = org.obsolete.newProperty(kctx, {
                        listOf(
                                Engine("default", "Engine 1", "This is engine 1",
                                        createIEngineManager = {
                                            object : IEngineManager {
                                                override fun start() {}
                                                override fun updateFilters() {}
                                                override fun stop() {}
                                            }
                                        }),
                                Engine("two", "Engine 2", "This is engine 2",
                                        createIEngineManager = {
                                            object : IEngineManager {
                                                override fun start() {}
                                                override fun updateFilters() {}
                                                override fun stop() {}
                                            }
                                        })
                        )
                    })
                    override val tunnelActiveEngine = org.obsolete.newProperty(kctx, { "default" })
                    override val tunnelDropCount = org.obsolete.newProperty(kctx, { 0 })
                    override val tunnelRecentDropped = org.obsolete.newProperty(kctx, { listOf<String>() })
                    override val repo = org.obsolete.newProperty(kctx, {
                        Repo(
                                contentPath = URL("http://example.com/content"),
                                locales = listOf(Locale("en")),
                                newestVersionCode = 10,
                                newestVersionName = "1.0",
                                downloadLinks = listOf(),
                                lastRefreshMillis = 0,
                                pages = mapOf()
                        )
                    })
                    override val localised = org.obsolete.newProperty(kctx, {
                        Localised(
                                content = URL("http://example.com/content"),
                                bug = URL("http://example.com/bug"),
                                feedback = URL("http://example.com/feedback"),
                                changelog = "changes",
                                lastRefreshMillis = 0L
                        )
                    })
                    override val apps = org.obsolete.newProperty(kctx, { emptyList<App>() })
                    override val filterConfig = org.obsolete.newProperty(kctx, {
                        FilterConfig(
                                cacheFile = File("dummy"),
                                exportFile = File("dummy2"),
                                cacheTTLMillis = 0,
                                repoURL = URL("http://example.com"),
                                fetchTimeoutMillis = 10 * 1000
                        )
                    })
                    override val tunnelConfig = org.obsolete.newProperty(kctx, { TunnelConfig("default") })
                    override val repoConfig = org.obsolete.newProperty(kctx, {
                        RepoConfig(
                                cacheFile = File("dummy"),
                                cacheTTLMillis = 0,
                                repoURL = URL("http://example.com"),
                                notificationCooldownMillis = 0,
                                fetchTimeoutMillis = 10 * 1000
                        )
                    })
                    override val versionConfig = org.obsolete.newProperty(kctx, {
                        VersionConfig(
                                appName = "app",
                                appVersionCode = 9,
                                appVersion = "0.9",
                                coreVersion = "0.9",
                                uiVersion = "0.9"
                        )
                    })
                }
            }
        }
    }

    @Test fun serialiser_basic() {
        Kovenant.testMode()
        val kctx = Kovenant.context
        val module = newDeps(kctx)
        val kodein = Kodein {
            import(module)
        }
        val s: Filters = kodein.instance()

        val sourceProvider = { sourceId: String -> FilterSourceSingle() }

        val serialiser = FilterSerializer(s, sourceProvider)

        val f1 = Filter(
                id = "f1",
                source = FilterSourceSingle("example.com"),
                credit = "credit-url",
                active = true,
                whitelist = false,
                localised = LocalisedFilter("filter name", "filter comment")
        )

        val f2 = Filter(
                id = "f2",
                source = FilterSourceSingle("example2.com"),
                active = false,
                whitelist = false,
                localised = LocalisedFilter("filter2 name")
        )

        val f3 = Filter(
                id = "f3",
                source = FilterSourceSingle("example3.com"),
                active = true,
                whitelist = true,
                localised = LocalisedFilter("filter3 name", "filter3\ncomment\nlol")
        )

        var serialised = serialiser.serialise(listOf(f1, f2, f3))

        // Total number of lines produced
        assertEquals(27, serialised.size)

        // Ordering
        assertEquals("0", serialised[0])
        assertEquals("1", serialised[9])
        assertEquals("2", serialised[18])

        // IDs
        assertEquals("f1", serialised[1])
        assertEquals("f2", serialised[10])
        assertEquals("f3", serialised[19])

        // Various arbitrary chosen fields
        assertEquals("example.com", serialised[6])
        assertEquals("single", serialised[14])
        assertEquals("active", serialised[3])
        assertEquals("inactive", serialised[12])
        assertEquals("whitelist", serialised[20])
        assertEquals("blacklist", serialised[2])

        // Localised optional info
        assertEquals("filter name", serialised[7])
        assertEquals("filter comment", serialised[8])
        assertEquals("", serialised[17])
        assertEquals("filter3\\ncomment\\nlol", serialised[26])


        // Deserialise now. Change some fields for more interesting case.
        serialised = serialised.toMutableList()
        serialised[0] = "3"
        serialised[6] = "new-example.com"
        serialised[12] = "active"
        serialised[17] = "new comment"
        val deserialised = serialiser.deserialise(serialised)

        // Total number of filters deserialised
        assertEquals(3, deserialised.size)

        // Ordering
        assertEquals("f2", deserialised[0].id)
        assertEquals("f3", deserialised[1].id)
        assertEquals("f1", deserialised[2].id)

        // Various deserialised fields
        assertEquals("credit-url", deserialised[2].credit)
        assertEquals(true, deserialised[2].active)
        assertEquals(false, deserialised[2].whitelist)
        assertEquals("filter2 name", deserialised[0].localised!!.name)
        assertEquals("example3.com", deserialised[1].source.toUserInput())
        assertEquals("filter3\ncomment\nlol", deserialised[1].localised!!.comment)

        // Fields changed by hand
        assertEquals("new-example.com", deserialised[2].source.toUserInput())
        assertEquals(true, deserialised[0].active)
        assertEquals("new comment", deserialised[0].localised!!.comment)
    }
}
