package gs

import org.junit.Assert.fail

fun wait(f: () -> Boolean) {
    for (i in 1..5) {
        if (f()) return
        Thread.sleep(100)
    }
}

fun assertThrows(f: () -> Unit) {
    try {
        f()
        fail("did not throw expected exception")
    } catch (e: Exception) {}
}

