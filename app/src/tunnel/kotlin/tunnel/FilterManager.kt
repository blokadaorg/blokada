package tunnel

import android.text.TextUtils.isEmpty
import com.github.michaelbull.result.Err
import com.github.michaelbull.result.mapBoth
import core.*
import org.acra.ACRA.log
import java.net.URL
// source example is filter.FilterSourceLink@5110feb2
// Result example is com.github.michaelbull.result.Result$Companion@1d61cff5
// fetched example is [wpad.wctel.net, i.scdn.co, spot.com.wctel.net]
// after this goes to "fun set" in Blockada.kt
internal class FilterManager(
        private val doFetchRuleset: (IFilterSource, MemoryLimit, listtype:Boolean) -> Result<Ruleset> = { source, limit, listtype: Boolean ->
            if (source.size() <= limit) Result.of {
                var fetched= when (listtype){
                    true -> source.fetch()
                    false -> source.fetchwildcard()
                }
                if (fetched.size == 0 && source.id() != "app")
                    throw Exception("failed to fetch ruleset (size 0)")
                else fetched
            }
            else Err(Exception("failed fetching rules, memory limit reached: $limit"))

        },
        private val doValidateRulesetCache: (Filter) -> Boolean = {
            it.source.id in listOf("app") ||
            it.lastFetch + 86400 * 1000 > System.currentTimeMillis()
        },
        private val doFetchFiltersFromRepo: (Url) -> Result<Set<Filter>> = {
            val serializer = FilterSerializer()
            Result.of { serializer.deserialise(loadGzip(openUrl(URL(it), 10 * 1000)))


            }
        },
        private val doProcessFetchedFilters: (Set<Filter>) -> Set<Filter> = { it },
        private val doValidateFilterStoreCache: (FilterStore) -> Boolean = {
            it.cache.isNotEmpty() && it.lastFetch + 86400 * 1000 > System.currentTimeMillis()
        },
        private val doLoadFilterStore: (AndroidKontext) -> Result<FilterStore> = Persistence.filters.load,
        private val doSaveFilterStore: (FilterStore) -> Result<Any> = Persistence.filters.save,
        private val doGetNow: () -> Time = { System.currentTimeMillis() },
        private val doGetMemoryLimit: () -> MemoryLimit = Memory.linesAvailable,
        private val doResolveFilterSource: (Filter) -> IFilterSource,
        internal val blockade: Blockade = Blockade()
) {

    private var store = FilterStore(lastFetch = 0)

    fun load(ktx: AndroidKontext) {
        doLoadFilterStore(ktx).mapBoth(
                success = {
                    ktx.v("loaded FilterStore from persistence", it.url, it.cache.size)
                    ktx.emit(Events.FILTERS_CHANGED, it.cache)
                    store = it
                },
                failure = {
                    ktx.e("failed loading FilterStore from persistence", it)
                }
        )
    }
// ktx example is core.AndroidKontext@398dd83f
    // it example is io.paperdb.Book@2e2510e3
    fun save(ktx: Kontext) {
        doSaveFilterStore(store).mapBoth( // after host are loaded
                success = { ktx.v("saved FilterStore to persistence", store.cache.size, store.url) },
                failure = { ktx.e("failed saving FilterStore to persistence", it) }
        )
    }

    fun setUrl(ktx: Kontext, url: String) {
        if (store.url != url) {
            store = store.copy(lastFetch = 0, url = url)
            ktx.v("changed FilterStore url", url)
        }
    }

    fun put(ktx: Kontext, new: Filter) {
        val old = store.cache.firstOrNull { it == new }
        store = if (old == null) {
            ktx.v("adding filter", new.id)
            val lastPriority = store.cache.maxBy { it.priority }?.priority ?: 0
            store.copy(cache = store.cache.plus(new.copy(priority = lastPriority + 1)))
        } else {
            ktx.v("updating filter", new.id)
            val newWithPreservedFields = new.copy(
                    whitelist = old.whitelist,
                    wildcard = old.wildcard,
                    priority = old.priority,
                    lastFetch = old.lastFetch
            )
            store.copy(cache = store.cache.minus(old).plus(newWithPreservedFields))
        }
        ktx.emit(Events.FILTERS_CHANGED, store.cache)
    }

    fun remove(ktx: Kontext, old: Filter) {
        ktx.v("removing filter", old.id)
        store = store.copy(cache = store.cache.minus(old))
        //store.cache.minus(old)
        ktx.emit(Events.FILTERS_CHANGED, store.cache)
    }

    fun removeAll(ktx: Kontext) {
        ktx.v("removing all filters")
        store = store.copy(cache = emptySet())
        ktx.emit(Events.FILTERS_CHANGED, store.cache)
    }

    fun invalidateCache(ktx: Kontext) {
        ktx.v("invalidating filters cache")
        val invalidatedFilters = store.cache.map { it.copy(lastFetch = 0) }.toSet()
        store = store.copy(cache = invalidatedFilters, lastFetch = 0)
    }

    fun getWhitelistedApps(ktx: Kontext) = {
        store.cache.filter {
            it.whitelist && it.active && it.source.id == "app" }.map {
            it.source.source

        }
    }()

    fun sync(ktx: Kontext) = {
        if (syncFiltersWithRepo(ktx)) {
            val success = syncRules(ktx)
            ktx.emit(Events.MEMORY_CAPACITY, Memory.linesAvailable())
            success
            true
        } else {
            false }
    }()
    private fun syncFiltersWithRepo(ktx: Kontext): Boolean {
        if (store.url.isEmpty()) {
            ktx.w("trying to sync without url set, ignoring")
            return false
        }

        if (!doValidateFilterStoreCache(store)) {
            ktx.v("syncing filters", store.url)
            ktx.emit(Events.FILTERS_CHANGING)
            doFetchFiltersFromRepo(store.url).mapBoth(
                    success = { builtinFilters ->
                        ktx.v("fetched. size:", builtinFilters.size)

                        val new = if (store.cache.isEmpty()) {
                            ktx.v("no local filters found, setting default configuration")
                            builtinFilters
                        } else {
                            ktx.v("combining with existing filters")
                            store.cache.map { existing ->
                                val f = builtinFilters.find { it == existing }
                                f?.copy(
                                        active = existing.active,
                                        hidden = existing.hidden,
                                        priority = existing.priority,
                                        lastFetch = existing.lastFetch
                                        // TODO: customcomment and name?
                                ) ?: existing
                            }.plus(builtinFilters.minus(store.cache)).toSet()
                        }

                        store = store.copy(cache = doProcessFetchedFilters(new).prioritised(),
                                lastFetch = doGetNow())f
                        ktx.v("synced", store.cache.size)
                        ktx.emit(Events.FILTERS_CHANGED, store.cache)
                    },
                    failure = {
                        ktx.e("failed syncing filters", it)
                    }
            )
        }

        return true
    }

    private fun syncRules(ktx: Kontext) = {
        val active = store.cache.filter { it.active }
        //TODO maybe clear clear() or remove() or onDestroy() !it.active here?
        val downloaded = mutableSetOf<Filter>()
        val wildcard = store.cache.filter{it.wildcard}
        wildcard.forEach {}
        active.forEach { filter ->
            if (!doValidateRulesetCache(filter)) {
                ktx.v("fetching ruleset", filter.id)
                ktx.emit(Events.FILTERS_CHANGING)
                if (filter !in wildcard) {
                    doFetchRuleset(doResolveFilterSource(filter), doGetMemoryLimit(), true).mapBoth(
                            success = {
                                blockade.set(ktx, filter.id, it)
                                downloaded.add(filter.copy(lastFetch = System.currentTimeMillis()))
                                ktx.v("saved", filter.id, it.size)
                            },
                            failure = {
                                ktx.e("failed fetching ruleset", filter.id, it)
                            })
                }
                else // wildcard list so don't null it for not being a complete domain name i.e. not ending with .com
                {
                    doFetchRuleset(doResolveFilterSource(filter), doGetMemoryLimit(), false).mapBoth(
                            success = {
                                blockade.set(ktx, filter.id, it)
                                downloaded.add(filter.copy(lastFetch = System.currentTimeMillis()))
                                ktx.v("saved wildcard ruleset", filter.id, it.size)
                            },
                            failure = {
                                ktx.e("failed fetching wildcard ruleset", filter.id, it)
                            })
                }
            }
        }

        //store = store.copy(cache = store.cache)
        val allowed = store.cache.filter { it.whitelist && it.active }.map { it.id }
        val denied = store.cache.filter { !it.whitelist && !it.wildcard && it.active }.map { it.id }
        val wildcardblock = store.cache.filter{ it.wildcard && it.active}.map{ it.id }
        ktx.v("attempting to build rules, wildcardblock/denied/allowed", denied.size, allowed.size)
        blockade.build(ktx, denied, wildcardblock, allowed)

        allowed.size > 0 || denied.size > 0
    }()

}
