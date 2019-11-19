package core

import org.junit.Test

class LogTest {
    @Test fun log_basics() {
        val log = DefaultLog("tag", writer = systemWriter, exceptionWriter = systemExceptionWriter)
        log.e("expected error")
        log.w("expected warning")
        log.v("verbose")
    }
}
