package tunnel

import core.Kontext
import core.Result
import org.junit.Assert
import org.junit.Test

class BlockadeTest {

    private fun fixture(memoryLimit: () -> MemoryLimit = { 999 }) = {
        val deny1 = Ruleset().apply { addAll(listOf("a", "b", "c")) }
        val deny2 = Ruleset().apply { addAll(listOf("b", "c", "d")) }
        val allow1 = Ruleset().apply { addAll(listOf("b", "d", "e")) }
        val allow2 = Ruleset().apply { addAll(listOf("f")) }

        Blockade(
                doLoadRuleset = { it -> Result.of {
                    when (it) {
                        "deny1" -> deny1
                        "deny2" -> deny2
                        "allow1" -> allow1
                        "allow2" -> allow2
                        else -> throw Exception("unknown ruleset")
                    }
                }},
                doSaveRuleset = { _, _ -> Result.of { true } },
                doGetRulesetSize = { it -> Result.of {
                    when (it) {
                        "deny1" -> deny1.size
                        "deny2" -> deny2.size
                        "allow1" -> allow1.size
                        "allow2" -> allow2.size
                        else -> throw Exception("unknown ruleset")
                    }
                }},
                doGetMemoryLimit = memoryLimit
        )
    }()

    @Test fun blockade_build() {
        val blockade = fixture()
        val ktx = Kontext.forTest("blockade.build()")

        blockade.build(ktx, deny = listOf("deny1", "deny2"), allow = listOf("allow1", "allow2"))

        Assert.assertTrue(blockade.denied("a"))
        Assert.assertTrue(blockade.denied("b"))
        Assert.assertTrue(blockade.denied("c"))
        Assert.assertTrue(blockade.denied("d"))

        Assert.assertTrue(blockade.allowed("b"))
        Assert.assertTrue(blockade.allowed("d"))
        Assert.assertTrue(blockade.allowed("e"))
        Assert.assertTrue(blockade.allowed("f"))

        Assert.assertFalse(blockade.denied("f"))
        Assert.assertFalse(blockade.allowed("a"))
    }

    @Test fun blockade_memory() {
        // Simulate memory decreasing after each list being loaded
        val memory = listOf(6, 3, 0) // Number of rules that can still fit
        var mIndex = 0
        val blockade = fixture(memoryLimit = {
            if (mIndex < 3) memory[mIndex++] else 0
        })
        val ktx = Kontext.forTest("blockade.build()")

        blockade.build(ktx, deny = listOf("deny1", "deny2"), allow = listOf("allow1", "allow2"))

        Assert.assertTrue(blockade.allowed("e"))
        Assert.assertFalse(blockade.allowed("f"))
    }
}
