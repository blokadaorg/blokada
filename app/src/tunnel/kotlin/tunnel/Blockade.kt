package tunnel

import com.github.michaelbull.result.mapBoth
import core.Kontext
import android.util.Log
import core.Result
import filter.DASH_ID_WHITELIST
import org.acra.ACRA.log
import tunnel.Persistence.Companion.filters
import java.util.Collections.addAll
import java.util.Collections.indexOfSubList

internal class Blockade(
        private val doLoadRuleset: (FilterId) -> Result<Ruleset> = Persistence.rules.load,
        private val doGetRulesetSize: (FilterId) -> Result<Int> = Persistence.rules.size,
        private val doGetMemoryLimit: () -> MemoryLimit = Memory.linesAvailable,
        private var wildcardRuleset: Ruleset = Ruleset(),
        private var whitelistRuleset: Ruleset = Ruleset(),
        private var blacklistRuleset: Ruleset = Ruleset(),
        private val doSaveRuleset: (FilterId, Ruleset) -> Result<Any> = Persistence.rules.save
) {
    // deny is name of list i.e b_engergized_blu
    //ktx is core.AndroidKontext@d3c0e1c

    fun build(ktx: Kontext, blacklist: List<FilterId>, wildcard: List<FilterId>, whitelist: List<FilterId>) {
        ktx.emit(Events.RULESET_BUILDING)
        var order = 1 // 1 for whitelist, 2 for wildcard_block, 3 for block
        whitelistRuleset.clear()
        whitelistRuleset = buildRuleset(ktx, order, whitelist)
        order = 2
        wildcardRuleset.clear()
        wildcardRuleset = buildRuleset(ktx, order, wildcard)
        order = 3
        blacklistRuleset.clear()
        blacklistRuleset = buildRuleset(ktx, order, blacklist)
        Log.d("Events.Ru", "blacklistRuleset size is " + blacklistRuleset.size + " wildcard size is " + wildcardRuleset.size + " whitelistRuleset size is " + whitelistRuleset.size)
        ktx.emit(Events.RULESET_BUILT, Triple(wildcardRuleset.size, blacklistRuleset.size, whitelistRuleset.size))
    }

    private fun buildRuleset(ktx: Kontext, order: Int, filters: List<FilterId>): Ruleset {
        var ruleset = Ruleset()
        if (filters.isEmpty()) return ruleset
        doLoadRuleset(filters.first()).mapBoth(
                success = { firstRuleset ->
                    ruleset = firstRuleset
                    filters.drop(1).forEach { nextFilter ->
                        if (ruleset.size < doGetMemoryLimit()) {
                            doLoadRuleset(nextFilter).mapBoth(
                                    success = { ruleset.addAll(it) },
                                    failure = { ktx.e("could not load ruleset", nextFilter, it) }
                            )
                        } else {
                            ktx.e("memory limit reached, skipping ruleset", nextFilter,
                                       doGetMemoryLimit(), ruleset.size)
                        }
                    }
                },
                failure = {
                    ktx.e("could not load first ruleset", filters.first(), it)
                }
        )
        if (order == 3) {
            var orignalrulesize = ruleset.size
            //TODO add button that says "Octomize" in advanced settings. have that button switch the below var octomize on/off.
            // Having octomize = true reduces list by about 20% and thus saves memory but takes a little longer to update.
            // update time is an issue due to the fact that blokada seems to completely re-download each list and do the update process four times.
            // faedrak said he thinks the issue is: the function gets called asynchron based on changes of a variable but has no check for other already running instances."
            var octomize = true
            if ( wildcardRuleset.size==0)
                octomize = false
            var counter = orignalrulesize - ruleset.size // because some were removed from whitelist
            val arraylist = ruleset.toString().split(",")//", ", "[", "]")
            ruleset.removeAll(whitelistRuleset)
            ruleset.removeAll(wildcardRuleset)
            if (octomize == true) {
                for (item in arraylist) {
                    var iit = item
                    iit = iit.removePrefix("[")
                    iit = iit.removeSuffix("]")
                    iit = iit.trim()
                    counter++
                    if (inwildcardlist(iit)) {
                        ruleset.remove(iit)
                        // makes process much faster when using Log.d on large list to only see one out of 2500 host
                        if (counter%1000==1)
                        // detailed Log.d version
                        // android.util.Log.d("skipped", "number of host left to evaluate: " + (orignalrulesize-counter)+ " orignal number of host: " + orignalrulesize + " octomized number of host in list: " + ruleset.size + "  percent finished is: " +((counter*100)/orignalrulesize) +  "% percent saved is: " + (((orignalrulesize - ruleset.size)*100)/counter)+ "% " + orignalrulesize +" " + ruleset.size + " " + counter + " host name: " + iit + " memory is " + Runtime.getRuntime().freeMemory() + " "  )
                        // easy view Log.d version
                         android.util.Log.d("skipped", ""+ (orignalrulesize-counter)+ " " + orignalrulesize + " " + ruleset.size + "  percent finished is " +((counter*100)/orignalrulesize) +  "% percent saved is " + (((orignalrulesize - ruleset.size)*100)/counter)+ "% " + orignalrulesize +" " + ruleset.size + " " + counter + " " + iit + " memory is " + Runtime.getRuntime().freeMemory() + " "  )
                    } else {
                        // makes process much faster when using Log.d on large list to only see one out of 2500 host
                        if (counter%1000==2500)
                        // detailed Log.d version
                        // android.util.Log.d("allowed", "number of host left to evaluate: " + (orignalrulesize-counter)+ " orignal number of host: " + orignalrulesize + " octomized number of host in list: " + ruleset.size + "  percent finished is: " +((counter*100)/orignalrulesize) +  "% percent saved is: " + (((orignalrulesize - ruleset.size)*100)/counter)+ "% " + orignalrulesize +" " + ruleset.size + " " + counter + " host name: " + iit + " memory is " + Runtime.getRuntime().freeMemory() + " "  )
                        // easy view Log.d version
                         android.util.Log.d("allowed", ""+ (orignalrulesize-counter)+ " " + orignalrulesize + " " + ruleset.size + "  percent finished is " +((counter*100)/orignalrulesize) +  "% percent saved is " + (((orignalrulesize - ruleset.size)*100)/counter)+ "% " + orignalrulesize +" " + ruleset.size + " " + counter + " " + iit + " memory is " + Runtime.getRuntime().freeMemory() + " "  )
                    }
                }
                Log.d("octomization", "finshed " + "memory saved " + (((orignalrulesize - ruleset.size) * 100) / counter) + "%")
                // debug for test use very small host list i.e.     https://gist.githubusercontent.com/Thomas499/266be112dd2661d602e26c6a0b01b983/raw
                //    Log.d("octomization","ruleset is " + ruleset)
                return ruleset
            }
        }
        var tempname = ""
        if (order == 1)
            tempname = "whitelist"
        if (order == 2)
            tempname = "Wildcard"
        if (order == 3)
            tempname = "blacklist"
        log.d("ruleset", "ruleset for " + tempname + " is " + ruleset)
        return ruleset
    }

    fun set(ktx: Kontext, id: FilterId, ruleset: Ruleset) {
        android.util.Log.d("fun Blockade.kt saved ", "" + id + ruleset)
        doSaveRuleset(id, ruleset).mapBoth(
                success = { ktx.v("saved ruleset", id, ruleset.size) },
                failure = { ktx.e("failed to save ruleset", id, it) }
        )
    }

    fun inblacklist(host: String): Boolean {
        return blacklistRuleset.contains(host)
    }

    fun inwhitelist(host: String): Boolean {
        return whitelistRuleset.contains(host)
    }

    fun inwildcardlist(host: String): Boolean {
        for (item in wildcardRuleset) {
            if (host.contains(item))
                return true
        }
        return false
    }
}

