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

        blockade.build(ktx, blacklist = listOf("deny1", "deny2"), whitelist = listOf("allow1", "allow2"), wildcard = "tom")

        Assert.assertTrue(blockade.inblacklist("a"))
        Assert.assertTrue(blockade.inblacklist("b"))
        Assert.assertTrue(blockade.inblacklist("c"))
        Assert.assertTrue(blockade.inblacklist("d"))

        Assert.assertTrue(blockade.inwhitelist("b"))
        Assert.assertTrue(blockade.inwhitelist("d"))
        Assert.assertTrue(blockade.inwhitelist("e"))
        Assert.assertTrue(blockade.inwhitelist("f"))

        Assert.assertFalse(blockade.inblacklist("f"))
        Assert.assertFalse(blockade.inwhitelist("a"))
    }

    @Test fun blockade_memory() {
        // Simulate memory decreasing after each list being loaded
        val memory = listOf(6, 3, 0) // Number of rules that can still fit
        var mIndex = 0
        val blockade = fixture(memoryLimit = {
            if (mIndex < 3) memory[mIndex++] else 0
        })
        val ktx = Kontext.forTest("blockade.build()")

        blockade.build(ktx, blacklist = listOf("deny1", "deny2"), whitelist = listOf("allow1", "allow2"))

        Assert.assertTrue(blockade.inwhitelist("e"))
        Assert.assertFalse(blockade.inblacklist("f"))
    }
}
