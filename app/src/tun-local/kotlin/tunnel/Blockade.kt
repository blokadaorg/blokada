package tunnel

import com.github.michaelbull.result.mapBoth
import core.Result
import core.e
import core.emit
import core.v
import org.blokada.R

internal abstract class Blockade(
        private val doLoadRuleset: (FilterId) -> Result<Ruleset> = Persistence.rules.load,
        private val doSaveRuleset: (FilterId, Ruleset) -> Result<Any> = Persistence.rules.save,
        private val doGetRulesetSize: (FilterId) -> Result<Int> = Persistence.rules.size,
        private val doGetMemoryLimit: () -> MemoryLimit = Memory.linesAvailable,
        private var denyRuleset: Ruleset = Ruleset(),
        private var allowRuleset: Ruleset = Ruleset()
) {

    open fun afterRulesetsBuilt(denyRuleset: Ruleset, allowRuleset: Ruleset) {}

    fun build(deny: List<FilterId>, allow: List<FilterId>) {
        emit(TunnelEvents.RULESET_BUILDING)
        denyRuleset.clear()
        denyRuleset = buildRuleset(deny)
        allowRuleset.clear()
        allowRuleset = buildRuleset(allow)
        afterRulesetsBuilt(denyRuleset, allowRuleset)
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
                            // TODO: somewhere else..
                            showSnack(R.string.home_filters_memory_error)
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

    abstract fun denied(host: String): Boolean

    abstract fun allowed(host: String): Boolean

}

internal class BasicBlockade(
        private val doLoadRuleset: (FilterId) -> Result<Ruleset> = Persistence.rules.load,
        private val doSaveRuleset: (FilterId, Ruleset) -> Result<Any> = Persistence.rules.save,
        private val doGetRulesetSize: (FilterId) -> Result<Int> = Persistence.rules.size,
        private val doGetMemoryLimit: () -> MemoryLimit = Memory.linesAvailable,
        private var denyRuleset: Ruleset = Ruleset(),
        private var allowRuleset: Ruleset = Ruleset()
): Blockade(
        doLoadRuleset = doLoadRuleset,
        doSaveRuleset = doSaveRuleset,
        doGetRulesetSize = doGetRulesetSize,
        doGetMemoryLimit = doGetMemoryLimit,
        denyRuleset = denyRuleset,
        allowRuleset = allowRuleset
) {

    override fun denied(host: String): Boolean {
        return denyRuleset.contains(host)
    }

    override fun allowed(host: String): Boolean {
        return allowRuleset.contains(host)
    }
}

internal class WildcardBlockade(
        private val doLoadRuleset: (FilterId) -> Result<Ruleset> = Persistence.rules.load,
        private val doSaveRuleset: (FilterId, Ruleset) -> Result<Any> = Persistence.rules.save,
        private val doGetRulesetSize: (FilterId) -> Result<Int> = Persistence.rules.size,
        private val doGetMemoryLimit: () -> MemoryLimit = Memory.linesAvailable,
        private var denyRuleset: Ruleset = Ruleset(),
        private var allowRuleset: Ruleset = Ruleset(),
        private var wildcardDenyRuleset: Ruleset = Ruleset(),
        private var wildcardAllowRuleset: Ruleset = Ruleset()
): Blockade(
        doLoadRuleset = doLoadRuleset,
        doSaveRuleset = doSaveRuleset,
        doGetRulesetSize = doGetRulesetSize,
        doGetMemoryLimit = doGetMemoryLimit,
        denyRuleset = denyRuleset,
        allowRuleset = allowRuleset
) {

    override fun afterRulesetsBuilt(denyRuleset: Ruleset, allowRuleset: Ruleset) {
        wildcardDenyRuleset = Ruleset().apply { addAll(denyRuleset.filter { it.startsWith("*.") }) }
        wildcardAllowRuleset = Ruleset().apply { addAll(allowRuleset.filter { it.startsWith("*.") }) }
        wildcardDenyRuleset = Ruleset().apply { addAll(wildcardDenyRuleset.map { it.removePrefix("*.") }) }
        wildcardAllowRuleset = Ruleset().apply { addAll(wildcardAllowRuleset.map { it.removePrefix("*.") }) }

        v("WildcardBlockade configured, deny/allow:", wildcardDenyRuleset.size,
                wildcardAllowRuleset.size)
    }

    override fun denied(host: String): Boolean {
        return denyRuleset.contains(host) || wildcardDenyRuleset.firstOrNull {
            host.endsWith(it)
        } != null
    }

    override fun allowed(host: String): Boolean {
        return allowRuleset.contains(host) || wildcardAllowRuleset.firstOrNull {
            host.endsWith(it)
        } != null
    }
}
