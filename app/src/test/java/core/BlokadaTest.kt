package core

import filter.FilterSourceDescriptor
import kotlinx.coroutines.experimental.async
import kotlinx.coroutines.experimental.channels.Channel
import kotlinx.coroutines.experimental.channels.ReceiveChannel
import kotlinx.coroutines.experimental.launch
import kotlinx.coroutines.experimental.runBlocking
import org.junit.Assert.*
import org.junit.Test
import java.net.URL

/**
 * Goals
 * - api for the entire app
 * - define its functions clearly
 * - prepare for using this api in flutter, or other integrations
 * - prepare for automated tests
 *
 * Blokada functions
 * - DNS blocker / forwarder / firewall
 * - IP firewall (app-specific)
 * - Content blocker in browsers (or other targeted ad blocking mechanisms)
 *
 * adblocking, dns changer, firewall, vpn
 *
 * Commands
 * filters refresh
 * filters add domain
 * filters add file
 * filters apply
 *
 * set enabled true
 * set persistence sharedpreferences
 * set persistence file file://dupadupa
 * set keep-alive true
 * set notifications false
 * set permissions vpn true // invokes the vpn dialog
 *
 * get enabled
 * get persistence
 * get keep-alive
 * get notifications
 * get permissions vpn
 *
 */

class BlokadaTest {

    @Test
    fun coroutines_basics() {
        val c1 = Channel<Any>()
        val c2 = Channel<Any>()
        launch {
            for (c in c1) {
                c2.send(c)
            }
            c2.close()
            c2.close()
        }

        async {
            c1.send("hello")
            c1.close()
        }

        runBlocking {
            val got = c2.receive()
            assertEquals("hello", got)
        }
    }

    @Test
    fun filters_basics() {
        TEST = true
        class FakeFilterSource(var hosts: List<String>) : IFilterSource {
            override fun fetch(): List<String> {
                return hosts
            }

            override fun fromUserInput(vararg string: String): Boolean {
                throw Exception()
            }

            override fun toUserInput(): String {
                throw Exception()
            }

            override fun serialize(): String {
                throw Exception()
            }

            override fun deserialize(string: String, version: Int): IFilterSource {
                throw Exception()
            }

            override fun id(): String {
                return "fake"
            }
        }

        val blacklisted1 = Filter(
                id = "b1",
                source = FilterSourceDescriptor("fake", "host1.com;host2.com"),
                active = true,
                priority = 0
        )

        val blacklisted2 = Filter(
                id = "b2",
                source = FilterSourceDescriptor("fake", "host2.com;host3.com"),
                active = true,
                priority = 1
        )

        val blacklisted_inactive = Filter(
                id = "b3",
                source = FilterSourceDescriptor("fake", "host4.com"),
                active = false
        )

        val whitelisted1 = Filter(
                id = "w1",
                source = FilterSourceDescriptor("fake", "host2.com;host4.com"),
                whitelist = true,
                active = false,
                priority = 2
        )

        val savedHosts = {
            setOf(
                    HostsCache(
                            id = "b1",
                            cache = setOf("host1-old.com", "host2.com", "host3-old.com")
                    ),
                    HostsCache(
                            id = "b2",
                            cache = setOf("host2.com", "host3.com")
                    )
            )
        }

        var isCacheValid = true

        val cmd = filtersActor(
                url = { URL("http://localhost") },
                loadFilters = { FiltersCache(setOf(blacklisted1, blacklisted2, whitelisted1)) },
                saveFilters = {},
                loadHosts = { savedHosts() },
                saveHosts = {},
                downloadFilters = { emptySet() },
                getSource = { descriptor, id -> FakeFilterSource(descriptor.source.split(";")) },
                isCacheValid = { isCacheValid }
        )

        runBlocking {
            val r = MonitorFilters()
            cmd.send(r)
            val filtersChannel = r.deferred.await()
            filtersChannel.receive() // First output is always current value

            val r2 = MonitorHostsCache()
            cmd.send(r2)
            val cacheChannel = r2.deferred.await()
            cacheChannel.receive()

            // Check if we load saved cache
            cmd.send(LoadFilters())
            var f = filtersChannel.receive()
            assertEquals(3, f.size)
            assertEquals(2, f.filter { it.active }.size)
            assertEquals(1, f.filter { it.whitelist }.size)
            var c = cacheChannel.receive()
            assertTrue(c.contains("host1-old.com"))
            assertTrue(c.contains("host3.com"))

            // We should not download anything if cache is still valid
            cmd.send(SyncHostsCache())
            c = cacheChannel.receive()
            assertTrue(c.contains("host1-old.com"))

            // Invalid cache should be refreshed
            isCacheValid = false
            cmd.send(SyncHostsCache())
            c = cacheChannel.receive()
            assertFalse(c.contains("host1-old.com"))
            assertTrue(c.contains("host1.com"))

            // Inactive filters should be ignored (also test if priority is incremented)
            cmd.send(UpdateFilter(blacklisted_inactive.id, blacklisted_inactive))
            f = filtersChannel.receive()
            assertEquals(3, f.first { it.id == blacklisted_inactive.id }.priority)
            cmd.send(SyncHostsCache())
            c = cacheChannel.receive()
            assertFalse(c.contains("host4.com"))

            // Activated filters should be respected
            val b3 = blacklisted_inactive.alter(newActive = true)
            cmd.send(UpdateFilter(b3.id, b3))
            cmd.send(SyncHostsCache())
            c = cacheChannel.receive()
            filtersChannel.receive()
            assertTrue(c.contains("host4.com"))

            // Whitelist removes blacklisted hosts
            val w = whitelisted1.alter(newActive = true)
            cmd.send(UpdateFilter(w.id, w))
            cmd.send(SyncHostsCache())
            c = cacheChannel.receive()
            filtersChannel.receive()
            assertFalse(c.contains("host2.com"))
            assertFalse(c.contains("host4.com"))

            // Deactivating list removes corresponding hosts
            val b1 = blacklisted1.alter(newActive = false)
            cmd.send(UpdateFilter(b1.id, b1))
            cmd.send(SyncHostsCache())
            c = cacheChannel.receive()
            filtersChannel.receive()
            assertFalse(c.contains("host1.com"))
        }
    }
}

fun handleChannel(name: String, c: ReceiveChannel<Any>) = launch {
    for (value in c) {
        when {
            value is Exception -> {
                System.err.println("$name: ${value.message}")
//            value.printStackTrace()
            }
            else -> {
                System.out.println("$name: $value")
            }
        }
    }
}

