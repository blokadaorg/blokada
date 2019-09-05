package tunnel

import com.github.michaelbull.result.Err
import com.github.michaelbull.result.mapBoth
import core.*
import java.net.URL

internal class FilterManager(
        private val doFetchRuleset: (IFilterSource, MemoryLimit) -> Result<Ruleset> = { source, limit ->
            if (source.size() <= limit) Result.of {
                val fetched = source.fetch()
                if (fetched.size == 0 && source.id() != "app")
                    throw Exception("failed to fetch ruleset (size 0)")
                else fetched
            }
            else Err(Exception("failed fetching rules, memory limit reached: $limit"))
        },
        private val doValidateRulesetCache: (Filter) -> Boolean = {
            it.source.id in listOf("app") /*||
            it.lastFetch + 86400 * 1000 > System.currentTimeMillis()*/
        },
        private val doFetchFiltersFromRepo: (Url) -> Result<Set<Filter>> = {
            val serializer = FilterSerializer()
            Result.of { serializer.deserialise(loadGzip(openUrl(URL(it), 10 * 1000))) }
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

    fun save(ktx: Kontext) {
        doSaveFilterStore(store).mapBoth(
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

    fun findBySource(source: String) : Filter?{
        return store.cache.find { it.source.id == "app" && it.source.source == source }
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
        store.cache.filter { it.whitelist && it.active && it.source.id == "app" }.map {
            it.source.source
        }
    }()

    fun sync(ktx: Kontext) = {
        if (syncFiltersWithRepo(ktx)) {
            val success = syncRules(ktx)
            ktx.emit(Events.MEMORY_CAPACITY, Memory.linesAvailable())
            success
        } else false
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
                                lastFetch = doGetNow())
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
        val downloaded = mutableSetOf<Filter>()
        active.forEach { filter ->
            if (!doValidateRulesetCache(filter)) {
                ktx.v("fetching ruleset", filter.id)
                ktx.emit(Events.FILTERS_CHANGING)
                doFetchRuleset(doResolveFilterSource(filter), doGetMemoryLimit()).mapBoth(
                        success = {
                            blockade.set(ktx, filter.id, it)
                            downloaded.add(filter.copy(lastFetch = System.currentTimeMillis()))
                            ktx.v("saved", filter.id, it.size)
                        },
                        failure = {
                            ktx.e("failed fetching ruleset", filter.id, it)
                        }
                )
            }
        }

        store = store.copy(cache = store.cache - downloaded + downloaded)

        val allowed = store.cache.filter { it.whitelist && it.active }.map { it.id }
        val denied = store.cache.filter { !it.whitelist && it.active }.map { it.id }

        ktx.v("attempting to build rules, denied/allowed", denied.size, allowed.size)
        blockade.build(ktx, denied, allowed)
        allowed.size > 0 || denied.size > 0
    }()

}
