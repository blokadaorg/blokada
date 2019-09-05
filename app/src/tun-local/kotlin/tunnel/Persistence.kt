package tunnel

import android.content.Context
import com.github.michaelbull.result.*
import core.AndroidKontext
import core.FiltersCache
import core.Kontext
import core.Result

class Persistence {
    companion object {
        val rules = RulesPersistence()
        val filters = FiltersPersistence()
        val config = TunnelConfigPersistence()
        val request = RequestPersistence()
        val blocka = BlockaConfigPersistence()
    }
}

class RulesPersistence {
    val load = { id: FilterId ->
        Result.of { core.Persistence.paper().read<Ruleset>("rules:set:$id", Ruleset()) }
    }
    val save = { id: FilterId, ruleset: Ruleset ->
        Result.of { core.Persistence.paper().write("rules:set:$id", ruleset) }
        Result.of { core.Persistence.paper().write("rules:size:$id", ruleset.size) }
    }
    val size = { id: FilterId ->
        Result.of { core.Persistence.paper().read("rules:size:$id", 0) }
    }
}

class FiltersPersistence {
    val load = { ktx: AndroidKontext ->
        loadLegacy34(ktx)
                .or { loadLegacy35(ktx) }
                .or {
                    ktx.v("loading from the persistence", core.Persistence.paper().path)
                    Result.of { core.Persistence.paper().read("filters2", FilterStore()) }
                            .orElse { ex ->
                                if (core.Persistence.global.loadPath() != core.Persistence.DEFAULT_PATH) {
                                    ktx.w("failed loading from a custom path, resetting")
                                    core.Persistence.global.savePath(core.Persistence.DEFAULT_PATH)
                                    Result.of { core.Persistence.paper().read("filters2", FilterStore()) }
                                } else Err(Exception("failed loading from default path", ex))
                            }
                }
    }

    val save = { filterStore: FilterStore ->
        Result.of { core.Persistence.paper().write("filters2", filterStore) }
    }

    private fun loadLegacy34(ktx: AndroidKontext) = {
        if (core.Persistence.global.loadPath() != core.Persistence.DEFAULT_PATH)
            Err(Exception("custom persistence path detected, skipping legacy import"))
        else {
            val prefs = ktx.ctx.getSharedPreferences("filters", Context.MODE_PRIVATE)
            val legacy = prefs.getString("filters", "").split("^")
            prefs.edit().putString("filters", "").apply()
            val old = FilterSerializer().deserialise(legacy)
            if (old.isNotEmpty()) {
                ktx.v("loaded from legacy 3.4 persistence", old.size)
                Result.of { FilterStore(old, lastFetch = 0) }
            } else Err(Exception("no legacy found"))
        }
    }()

    private fun loadLegacy35(ktx: AndroidKontext) = {
        Result.of { core.Persistence.paper().read("filters2", FiltersCache()) }
                .andThen {
                    if (it.cache.isEmpty()) Err(Exception("no 3.5 legacy persistence found"))
                    else {
                        ktx.v("loaded from legacy 3.5 persistence")
                        Ok(FilterStore(
                                cache = it.cache.map {
                                    Filter(
                                            id = it.id,
                                            source = FilterSourceDescriptor(it.source.id, it.source.source),
                                            whitelist = it.whitelist,
                                            active = it.active,
                                            hidden = it.hidden,
                                            priority = it.priority,
                                            credit = it.credit,
                                            customName = it.customName,
                                            customComment = it.customComment
                                    )
                                }.toSet()
                        ))
                    }
                }
    }()
}

class TunnelConfigPersistence {
    val load = { ktx: Kontext ->
        Result.of { core.Persistence.paper().read<TunnelConfig>("tunnel:config", TunnelConfig()) }
                .mapBoth(
                        success = { it },
                        failure = { ex ->
                            ktx.w("failed loading TunnelConfig, reverting to defaults", ex)
                            TunnelConfig()
                        }
                )
    }

    val save = { config: TunnelConfig ->
        Result.of { core.Persistence.paper().write("tunnel:config", config) }
    }
}

class RequestPersistence(
        val load: (Int) -> Result<List<Request>> = { batch: Int ->
            Result.of { core.Persistence.paper().read<List<Request>>("requests:$batch", emptyList()) }
        },
        val saveBatch: (Int, List<Request>) -> Any = { batch: Int, requests: List<Request> ->
            Result.of { core.Persistence.paper().write("requests:$batch", requests) }
        },
        val batch_sizes: List<Int> = listOf(10, 100, 1000)
) {

    private val batch0 = mutableListOf<Request>()

    val batches = listOf(
            { batch0 },
            { load(1).getOr { emptyList() } },
            { load(2).getOr { emptyList() } }
    )

    val save = { request: Request ->
        batch0.add(0, request)
        saveBatch(0, batch0)
        rollIfNeeded()
    }

    fun rollIfNeeded() {
        for (i in 0 until batches.size) {
            val size = batch_sizes[i]
            val batch = batches[i]()

            if (batch.size > size) {
                if (i < batches.size - 1) {
                    val nextBatch = batches[i + 1]()
                    saveBatch(i + 1, batch + nextBatch)
                    saveBatch(i, emptyList())
                    (batch as? MutableList)?.clear()
                } else {
                    saveBatch(i, batch.subList(0, size))
                }
            } else break
        }
    }

    fun clear(){
        for (i in 0 until batches.size) {
            saveBatch(i, emptyList())
        }
    }
}

class BlockaConfigPersistence {
    val load = { ktx: Kontext ->
        Result.of { core.Persistence.paper().read<BlockaConfig>("blocka:config", BlockaConfig()) }
                .mapBoth(
                        success = { it },
                        failure = { ex ->
                            ktx.w("failed loading BlockaConfig, reverting to empty", ex)
                            BlockaConfig()
                        }
                )
    }

    val save = { config: BlockaConfig ->
        Result.of { core.Persistence.paper().write("blocka:config", config) }
    }
}
