package tunnel

import core.Kontext
import core.Result
import org.junit.Assert
import org.junit.Test

class FakeFiltersource(val id: String) : IFilterSource {
    override fun size() = 3

    override fun fetch(): LinkedHashSet<String>
            = LinkedHashSet<String>().apply { for (i in 0..3) add(id) }

    override fun fromUserInput(vararg string: String) = false

    override fun toUserInput() = id

    override fun serialize() = id

    override fun deserialize(string: String, version: Int) = FakeFiltersource(string)

    override fun id() = id

}

class FakeDownloadingFilterSource(val id: String, var downloadCount: Int = 0) : IFilterSource {
    override fun size() = 1

    override fun fetch(): LinkedHashSet<String> = {
        ++downloadCount
        LinkedHashSet<String>().apply { add(id) }
    }()

    override fun fromUserInput(vararg string: String) = false

    override fun toUserInput() = id

    override fun serialize() = id

    override fun deserialize(string: String, version: Int) = FakeDownloadingFilterSource(string)

    override fun id() = id

}

class FilterManagerTest {
    @Test fun manager_basics() {
        val inMemoryPersistance = mutableMapOf<FilterId, Ruleset>()
        val filters = setOf(
                Filter("id1", FilterSourceDescriptor("fake", "a"), active = true),
                Filter("id2", FilterSourceDescriptor("fake", "b"), active = true),
                Filter("id3", FilterSourceDescriptor("fake", "c"), active = true, whitelist = true)
        )
        val manager = FilterManager(
                doFetchFiltersFromRepo = { url -> Result.of { filters } },
                doGetMemoryLimit = { 999 },
                doResolveFilterSource = { FakeFiltersource(it.source.source) },
                blockade = Blockade(
                        doLoadRuleset = { id ->
                            Result.of { inMemoryPersistance.getOrElse(id, {throw Exception("cache miss")}) }
                        },
                        doSaveRuleset = { id, ruleset ->
                            Result.of { inMemoryPersistance[id] = ruleset }
                        }
                )
        )

        manager.sync(Kontext.forTest("sync"))
        Assert.assertTrue(manager.blockade.denied("a"))
        Assert.assertTrue(manager.blockade.denied("b"))
        Assert.assertFalse(manager.blockade.denied("c"))
        Assert.assertTrue(manager.blockade.allowed("c"))
    }

    @Test fun manager_persists() {
        val inMemoryPersistance = mutableMapOf<FilterId, Ruleset>()
        val filters = setOf(
                Filter("id1", FilterSourceDescriptor("fake", "a"), active = true)
        )
        val source = FakeDownloadingFilterSource("id1")
        val manager = FilterManager(
                doFetchFiltersFromRepo = { url -> Result.of { filters } },
                doGetMemoryLimit = { 999 },
                doResolveFilterSource = { source },
                blockade = Blockade(
                        doLoadRuleset = { id ->
                            Result.of { inMemoryPersistance.getOrElse(id, {throw Exception("cache miss")}) }
                        },
                        doSaveRuleset = { id, ruleset ->
                            Result.of { inMemoryPersistance[id] = ruleset }
                        }
                )
        )

        Assert.assertEquals(0, source.downloadCount)
        manager.sync(Kontext.forTest("sync"))
        Assert.assertEquals(1, source.downloadCount)
        manager.sync(Kontext.forTest("sync2"))
        Assert.assertEquals(1, source.downloadCount)
    }

    @Test fun manager_priority() {
        val f1 = Filter("1", FilterSourceDescriptor("fake", "1"))
        val f2 = Filter("2", FilterSourceDescriptor("fake", "2"))
        val f3 = Filter("3", FilterSourceDescriptor("fake", "3"))
        val manager = FilterManager(
                doLoadFilterStore = { _ -> Result.of { FilterStore(setOf(f1, f2, f3),
                        lastFetch = System.currentTimeMillis()) }},
                doResolveFilterSource = { FakeDownloadingFilterSource(it.id) }
        )

        var step = 0
        val ktx = Kontext.forTest()
        ktx.on(tunnel.Events.FILTERS_CHANGED) {
            when (step) {
                0 -> {
                    Assert.assertEquals(1, it.size)
                    Assert.assertEquals(1, it.first { it.id == "1" }.priority)
                    step++
                }
                1 -> {
                    Assert.assertEquals(2, it.size)
                    Assert.assertEquals(1, it.first { it.id == "1" }.priority)
                    Assert.assertEquals(2, it.first { it.id == "2" }.priority)
                    step++
                }
                2 -> {
                    Assert.assertEquals(2, it.size)
                    Assert.assertEquals(1, it.first { it.id == "1" }.priority)
                    Assert.assertEquals(2, it.first { it.id == "2" }.priority)
                    step++
                }
                3 -> {
                    Assert.assertEquals(3, it.size)
                    Assert.assertEquals(1, it.first { it.id == "1" }.priority)
                    Assert.assertEquals(2, it.first { it.id == "2" }.priority)
                    Assert.assertEquals(3, it.first { it.id == "3" }.priority)
                    step++
                }
            }
        }

        manager.put(ktx, f1)
        manager.put(ktx, f2)

        val newF1 = f1.copy(active = false, priority = 99) // Priority should be ignored
        manager.put(ktx, newF1)

        manager.put(ktx, f3)

        Assert.assertEquals(4, step)
    }
}
