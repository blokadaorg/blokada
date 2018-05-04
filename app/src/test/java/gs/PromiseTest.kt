package gs

import nl.komponents.kovenant.deferred
import nl.komponents.kovenant.task
import org.blokada.framework.wait
import org.junit.Test

/**
 * Let's see if promises do what they promise.
 */
class PromiseTest {
    @Test fun promise_willCallCallbacks() {
        var success = false
        task {} success { success = true }
        wait { success == true }
        assert(success == true)
        var fail = false
        task { throw RuntimeException("fail") } fail { fail = true }
        wait { fail == true }
        assert(fail == true)
    }

    @Test fun deferred_willCallCallbacks() {
        val def = deferred<Unit, Exception>()
        task { throw RuntimeException("fail") } fail { def.reject(it) }
        var fail = false
        def.promise fail { fail = true }
        wait { fail == true }
        assert(fail == true)
    }

}
