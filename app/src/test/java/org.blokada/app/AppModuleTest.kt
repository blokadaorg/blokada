package org.blokada.app

import com.github.salomonbrys.kodein.Kodein
import com.github.salomonbrys.kodein.bind
import com.github.salomonbrys.kodein.instance
import com.github.salomonbrys.kodein.singleton
import core.*
import filter.FilterSourceSingle
import nl.komponents.kovenant.Kovenant
import nl.komponents.kovenant.testMode
import org.obsolete.KContext
import org.obsolete.newConcurrentKContext
import org.blokada.framework.*
import org.junit.Test
import org.junit.Assert.*
import java.io.File
import java.net.URL
import java.util.*


class AppModuleTest {

    private var tunnelPerm = false

    private fun newDeps(kctx: Worker): Kodein.Module {
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
                    override val filtersCompiled = org.obsolete.newProperty(kctx, { setOf<String>() },
                            refresh = { filters().flatMap { it.hosts }.toSet() })
                    override val tunnelState = org.obsolete.newProperty(kctx, { TunnelState.INACTIVE })
                    override val tunnelPermission = org.obsolete.newProperty(kctx, { tunnelPerm })
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
            bind<Journal>() with singleton { mockJournal() }
            bind<IEngineManager>() with singleton { object : IEngineManager {
                override fun start() {}
                override fun updateFilters() {}
                override fun stop() {}
            } }
            bind<IPermissionsAsker>() with singleton { object: IPermissionsAsker {
                override fun askForPermissions() {}
            } }
            bind<IWatchdog>() with singleton { object: IWatchdog {
                override fun start() {}
                override fun stop() {}
                override fun test(): Boolean { return true }
            } }
        }
    }

    @Test fun appModule_basic() {
        Kovenant.testMode()
        val kctx = Kovenant.context
        val module = newDeps(kctx)
        val kodein = Kodein {
            import(module)
            import(newAppModule())
        }

        val s: Filters = kodein.instance()
        s.enabled %= true

        // Turn off if can't get permissions for the tunnel
        assertFalse(s.active())
        s.active %= true
        assertFalse(s.active())

        // But if you have permissions, turn on should work
        tunnelPerm = true
        s.active %= true
        assertTrue(s.active())

        // Turn off if no connection
        assertTrue(s.connection().connected)
        s.connection %= Connection(connected = false)
        assertFalse(s.active())
        assertTrue(s.restart())

        // Do not get back on automatically in case user turned it off
        s.enabled %= false
        s.connection %= Connection(connected = true)
        assertFalse(s.active())

        // Do not get back automatically even after the connection goes off and on
        s.connection %= Connection(connected = false)
        s.connection %= Connection(connected = true)
        assertFalse(s.active())

        // Do get back automatically if was enabled, and connection is back
        s.connection %= Connection(connected = false)
        s.connection %= Connection(connected = true)
        s.enabled %= true
        assertTrue(s.active())
        assertFalse(s.restart())

        // TunnelState should respond to enabled flag
        assertTrue(s.tunnelState(TunnelState.ACTIVE))
        s.active %= false
        assertTrue(s.tunnelState(TunnelState.INACTIVE))

        // Engine won't reload if not necessary
        s.active %= true
        s.restart %= false
        s.tunnelActiveEngine %= "default"
        assertTrue(s.tunnelActiveEngine("default"))
        assertFalse(s.restart())
        var gotRestarted = false
        s.restart.doWhenChanged().then { gotRestarted = s.restart() or gotRestarted }
        s.tunnelActiveEngine %= "default"
        assertFalse(gotRestarted)

        // Engine will reload if actually changed
        s.tunnelActiveEngine %= "two"
        assertTrue(gotRestarted)

        // Engine will reload to a proper one in case selected configuration is invalid
        gotRestarted = false
        s.tunnelActiveEngine %= "unknown"
        assertTrue(gotRestarted)
        assertTrue(s.tunnelActiveEngine("default"))

        // While updating, tunnel should go down and not restart
        assertTrue(s.tunnelState(TunnelState.ACTIVE))
        s.updating %= true
        s.restart %= true
        s.active %= false
        assertTrue(s.tunnelState(TunnelState.INACTIVE))
        s.active %= true
        assertTrue(s.tunnelState(TunnelState.ACTIVE))
        assertFalse(s.updating())

        // Whenever filters change, filtersCompiled should update
        assertEquals(0, s.filtersCompiled().size)
        s.filters %= listOf(Filter(
                id = "f1",
                source = FilterSourceSingle("example.com"),
                active = true,
                hosts = listOf("example.com", "2.example.com")
        ))
        assertEquals(2, s.filtersCompiled().size)
    }

    @Test fun appModule_threaded() {
        val kctx = newConcurrentKContext(j = mockJournal(), prefix = "state", tasks = 10)
        val module = newDeps(kctx)
        val kodein = Kodein {
            import(module)
            import(newAppModule())
        }

        val s: Filters = kodein.instance()

        // Turn off if can't get permissions for the tunnel
        assertFalse(s.active())
        s.active %= true
        wait { s.active(false) }
        assertFalse(s.active())

        // TunnelState should respond to enabled flag
        tunnelPerm = true
        s.active %= true
        wait { s.tunnelState(TunnelState.ACTIVE) }
        assertTrue(s.tunnelState(TunnelState.ACTIVE))
        s.active %= false
        wait { s.tunnelState(TunnelState.INACTIVE) }
        assertTrue(s.tunnelState(TunnelState.INACTIVE))
    }

    @Test fun appModule_start() {
        Kovenant.testMode()
        val kctx = Kovenant.context
        val module = newDeps(kctx)
        val kodein = Kodein {
            import(module)
            import(newAppModule())
        }

        val s: Filters = kodein.instance()

        // The app does start by itself (if enabled)
        tunnelPerm = true
        s.enabled %= true
        assertTrue(s.tunnelState(TunnelState.ACTIVE))
    }
}
