package core

import kotlinx.coroutines.experimental.Unconfined
import org.junit.Assert
import org.junit.Test

class EmitTest {
    @Test fun emit_basics() {
        val hello = "hello".newEvent()
        val anotherHello = "hello".newEvent()

        var count = 0
        val callback = { ++count; Unit }

        val emit = CommonEmit({ Kontext.forTest() })

        emit.on(hello, callback)
        Assert.assertEquals(0, count)

        emit.emit(anotherHello)
        Assert.assertEquals(0, count)

        emit.emit(hello)
        Assert.assertEquals(1, count)

        emit.emit(hello)
        Assert.assertEquals(2, count)

        emit.cancel(hello, callback)
        emit.emit(hello)
        Assert.assertEquals(2, count)
    }

    @Test fun emit_noDeepCopy() {
        val data = mutableListOf("a", "b")

        val emit = CommonEmit({ Kontext.forTest() })

        var received = emptyList<String>()
        val callback = { it: List<String> -> received = it }
        val event = "event".newEventOf<List<String>>()

        emit.on(event, callback)
        emit.emit(event, data)
        Assert.assertEquals(data, received)

        data.add("c")
        Assert.assertEquals("c", received[2])
    }

    @Test fun emit_sendsMostRecentEventOnSubscribe() {
        val emit = CommonEmit({ Kontext.forTest() })

        var received = 0
        val callback = { it: Int -> received = it }
        val event = "event".newEventOf<Int>()

        emit.emit(event, 1)

        Assert.assertEquals(0, received)
        emit.on(event, callback)
        Assert.assertEquals(1, received)
    }

    @Test fun emit_logsException() {
        var logged = 0
        val emit = CommonEmit({ Kontext.forTest(coroutineContext = Unconfined + newEmitExceptionLogger(
                Kontext.forTest("emit:exception",
                        log = object : Log {
                            override fun e(vararg msgs: Any) { logged++ }
                            override fun w(vararg msgs: Any) {}
                            override fun v(vararg msgs: Any) {}
                        })
        )) })

        val callback = { throw Exception("crash") }

        Assert.assertEquals(0, logged)
        val event = "event".newEvent()
        emit.on(event, callback)
        emit.emit(event)
        Assert.assertEquals(1, logged)
    }
}
