package core

import org.junit.Test

class KontextTest {
    @Test fun kontext_isTestable() {
        val ktx = Kontext.forTest("test")
    }
}
