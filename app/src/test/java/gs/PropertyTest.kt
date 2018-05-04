package gs

import gs.environment.newConcurrentWorker
import gs.environment.newSingleThreadedWorker
import gs.other.newConcurrentWorker
import gs.other.newSingleThreadedWorker
import gs.property.Persistence
import gs.property.newPersistedProperty
import gs.property.newProperty
import nl.komponents.kovenant.Kovenant
import nl.komponents.kovenant.testMode
import org.junit.Assert.*
import org.junit.Test

class PropertyTest {
    @Test fun property_api() {
        Kovenant.testMode()
        val kctx = Kovenant.context

        var shouldRefresh = false
        var calledInit = false
        var calledRefresh = false
        val property = newProperty(kctx,
                zeroValue = { "zero" },
                init = {
                    calledInit = true
                    "hi"
                },
                refresh = {
                    calledRefresh = true
                    "refreshed"
                },
                shouldRefresh = { shouldRefresh }
        )

        // Init called right after instantiation
        assertTrue(calledInit)
        val initialValue = property()
        assertEquals("hi", initialValue)

        // Refresh called only when it should be
        property()
        assertFalse(calledRefresh)
        property.refresh()
        assertFalse(calledRefresh)
        shouldRefresh = true
        property.refresh()
        val newValue = property()
        assertTrue(calledRefresh)
        assertEquals("refreshed", newValue)

        // Force refresh
        shouldRefresh = false
        calledRefresh = false
        property()
        assertFalse(calledRefresh)
        property.refresh(force = true, blocking = true)
        assertTrue((calledRefresh))

        // Setting and getting
        calledRefresh = false
        property %= "hello"
        assertEquals("hello", property())
        assertTrue(property("hello"))
        assertFalse(property("hi"))
        assertTrue(property("hello", "hi"))
        assertFalse(calledRefresh)

        // Async getter
        var asyncValue = ""
        property { asyncValue = it }
        assertEquals("hello", asyncValue)

        // Basic listener
        shouldRefresh = false
        var listenerCalled = false
        val listener = property.doWhenChanged().then { listenerCalled = true }
        assertFalse(listenerCalled)
        property %= "new"
        assertTrue(listenerCalled)

        // Assigning equal value - listener not called
        listenerCalled = false
        property %= "new"
        assertFalse(listenerCalled)

        // Assigning another value - listener called
        listenerCalled = false
        property %= "new2"
        assertTrue(listenerCalled)

        // Listener with condition not called when condition is false
        listenerCalled = false
        var secondListenerCalled = false
        property.doWhen { property("trigger") }.then { secondListenerCalled = true }
        property %= "not"
        assertTrue(listenerCalled)
        assertFalse(secondListenerCalled)

        // Listener with condition called when condition is true
        property %= "trigger"
        assertTrue(secondListenerCalled)

        // Cancel listener
        listenerCalled = false
        property.cancel(listener)
        property %= "new"
        assertFalse(listenerCalled)
    }

    @Test fun property_errors() {
        Kovenant.testMode({})
        val kctx = Kovenant.context

        val initFails = newProperty<String>(kctx,
                zeroValue = { "zero" },
                init = { throw Exception ("failed") },
                shouldRefresh = { true }
        )

        var shouldRefresh = true
        val refreshFails = newProperty(kctx,
                zeroValue = { "zero" },
                init = { "ok" },
                refresh = { throw Exception ("failed") },
                shouldRefresh = { shouldRefresh }
        )

        // Synchronous getter returns zero value
        assertEquals("zero", initFails())

        // Other getters do not throw either
        initFails {}
        initFails.refresh(blocking = true)

        // Async getter not called since there's no value to provide
        var asyncCalled = false
        initFails { asyncCalled = true }
        assertFalse(asyncCalled)

        // If only refresh call is failing, first sync get works just fine
        assertEquals("ok", refreshFails())

        // This one fails quitely (is that nice design?)
        refreshFails.refresh(blocking = true)

        // Other getters are quite usable
        var asyncValue = ""
        refreshFails { asyncValue = it }
        assertEquals("ok", asyncValue)
        assertTrue(refreshFails("ok"))

        // If no need to call refresh, property is usable
        shouldRefresh = false
        assertEquals("ok", refreshFails())
    }

    @Test fun property_persisted() {
        Kovenant.testMode()
        val kctx = Kovenant.context

        var persisted = "init"
        var calledRead = false
        var calledWrite = false
        val persistence = object: Persistence<String> {
            override fun read(current: String): String { calledRead = true; return persisted }
            override fun write(source: String) { calledWrite = true; persisted = source }
        }

        val property = newPersistedProperty(kctx, persistence, { "zero" })

        // Initial value is read from persistence
        assertEquals("init", property())
        assertTrue(calledRead)

        // Changes are persisted
        property %= "new"
        assertEquals("new", property())
        assertTrue(calledWrite)

        // Refresh reads from persistence
        calledRead = false
        property.refresh(blocking = true)
        assertEquals("new", property())
        assertTrue(calledRead)
    }

    @Test fun property_persistedWithRefresh() {
        Kovenant.testMode()
        val kctx = Kovenant.context

        var persisted = "init"
        val persistence = object: Persistence<String> {
            override fun read(current: String): String { return persisted }
            override fun write(source: String) { persisted = source }
        }

        val property = newPersistedProperty(kctx, persistence,
                zeroValue = { "zero" },
                refresh = { "refresh" },
                shouldRefresh = { true })

        // Refresh reads from refresh callback, and is executed automatically
        assertEquals("refresh", property())

        // Changes are not overwritten by the refresh callback
        property %= "new"
        assertEquals("new", property())
    }

    @Test fun property_persistedWithModification() {
        Kovenant.testMode()
        val kctx = Kovenant.context

        val persistence = object : Persistence<List<Int>> {
            override fun read(current: List<Int>): List<Int> {
                return current
            }

            override fun write(source: List<Int>) {}
        }

        val property = newPersistedProperty(kctx, persistence, { emptyList() })

        property %= property().plus(1)
        assertEquals(listOf(1), property())
        property %= property().plus(2)
        assertEquals(listOf(1, 2), property())
        property.refresh(blocking = true)
        assertEquals(listOf(1, 2), property())
        property %= property().plus(3)
        property.refresh(blocking = true)
        assertEquals(listOf(1, 2, 3), property())
    }

    @Test fun property_lazy() {
        Kovenant.testMode()
        val kctx = Kovenant.context

        val property = newProperty(kctx, { "lazy" })

        // Property value should be initialised on first get with any method
        assertTrue(property("lazy"))
    }

    @Test fun property_dowhen() {
        Kovenant.testMode()
        val kctx = Kovenant.context

        val property = newProperty(kctx, { "value" })

        // The listener should be called when the property gets initialised
        var called = false
        property.doWhenSet().then { called = true }
        assertTrue(called)

        // Any listener set after the property is initialised gets called immediatelly once
        var callCount = 0
        property.doWhenSet().then { callCount += 1 }
        assertEquals(1, callCount)

        // All listeners are called if property is set
        called = false
        property %= "value2"
        assertTrue(called)
        assertEquals(2, callCount)

        // Listeners are called even if value is set to equal value
        called = false
        property %= "value2"
        assertTrue(called)
        assertEquals(3, callCount)

        // This type of listener is not called immediately, only on value changed
        var calledLater = false
        var w = property.doWhenChanged().then { calledLater = true }
        assertFalse(calledLater)
        property %= "value3"
        assertTrue(calledLater)

        // Cancelling listener stops callbacks
        calledLater = false
        property.cancel(w)
        property %= "value2"
        assertFalse(calledLater)
    }

    @Test fun property_threaded() {
//        val kctx = newSingleThreadedWorker(j = mockJournal(), prefix = "property")
        val kctx = newConcurrentWorker(j = mockJournal(), prefix = "property", tasks = 10)
        val kctx2 = newSingleThreadedWorker(j = mockJournal(), prefix = "property3")
        val property = newProperty(kctx, { "value" }, shouldRefresh = { true })
        val property2 = newProperty(kctx, { property() + "2" })
        val property3 = newProperty(kctx2, { property() + "3" })

        // Simple value retrieval that happens on another thread and is synchronised to main
        assertEquals("value", property())

        // Synchronous get for a property that is dependent on another property - same thread
        assertEquals("value2", property2())

        // Synchronous get for a property that is dependent on another property - different threads
        assertEquals("value3", property3())

        // Two dependent properties scheduled to the same thread
//        var called = false
//        property.doWhen { property2("value2") }.then { called = true }
//        wait { called }
//        assertTrue(called)

        // Two dependent properties scheduld to separate threads
//        var called2 = false
//        property.doWhen { property3("value3") }.then { called2 = true }
//        wait { called2 }
//        assertTrue(called2)
    }

}
