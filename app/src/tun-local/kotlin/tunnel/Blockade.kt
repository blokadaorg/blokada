package tunnel

import com.github.michaelbull.result.mapBoth
import core.Result
import core.e
import core.emit
import core.v

internal class Blockade(
        private val doLoadRuleset: (FilterId) -> Result<Ruleset> = Persistence.rules.load,
        private val doSaveRuleset: (FilterId, Ruleset) -> Result<Any> = Persistence.rules.save,
        private val doGetRulesetSize: (FilterId) -> Result<Int> = Persistence.rules.size,
        private val doGetMemoryLimit: () -> MemoryLimit = Memory.linesAvailable,
        private var denyRuleset: Ruleset = Ruleset(),
        private var allowRuleset: Ruleset = Ruleset()
) {

    fun build(deny: List<FilterId>, allow: List<FilterId>) {
        emit(TunnelEvents.RULESET_BUILDING)
        denyRuleset.clear()
        denyRuleset = buildRuleset(deny)
        allowRuleset.clear()
        allowRuleset = buildRuleset(allow)
        emit(TunnelEvents.RULESET_BUILT, denyRuleset.size to allowRuleset.size)
    }

    private fun buildRuleset(filters: List<FilterId>): Ruleset {
        var ruleset = Ruleset()
        if (filters.isEmpty()) return ruleset
        doLoadRuleset(filters.first()).mapBoth(
                success = { firstRuleset ->
                    ruleset = firstRuleset
                    filters.drop(1).forEach { nextFilter ->
                        if (ruleset.size < doGetMemoryLimit()) {
                            doLoadRuleset(nextFilter).mapBoth(
                                    success = { ruleset.addAll(it) },
                                    failure = { e("could not load ruleset", nextFilter, it) }
                            )
                        } else {
                            e("memory limit reached, skipping ruleset", nextFilter,
                                    doGetMemoryLimit(), ruleset.size)
                        }
                    }
                },
                failure = {
                    e("could not load first ruleset", filters.first(), it)
                }
        )
        return ruleset
    }

    fun set(id: FilterId, ruleset: Ruleset) {
        doSaveRuleset(id, ruleset).mapBoth(
                success = { v("saved ruleset", id, ruleset.size) },
                failure = { e("failed to save ruleset", id, it) }
        )
    }

    fun denied(host: String): Boolean {
        return denyRuleset.contains(host)
    }

    fun allowed(host: String): Boolean {
        return allowRuleset.contains(host)
    }

}

