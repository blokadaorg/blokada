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
        private val doLoadFilterStore: () -> Result<FilterStore> = {
            val ctx = getActiveContext()!!
            Persistence.filters.load(ctx.ktx("persistence"))
        },
        private val doSaveFilterStore: (FilterStore) -> Result<Any> = Persistence.filters.save,
        private val doGetNow: () -> Time = { System.currentTimeMillis() },
        private val doGetMemoryLimit: () -> MemoryLimit = Memory.linesAvailable,
        private val doResolveFilterSource: (Filter) -> IFilterSource,
        internal val blockade: Blockade = Blockade()
) {

    private var store = FilterStore(lastFetch = 0)

    fun load() {
        doLoadFilterStore().mapBoth(
                success = {
                    v("loaded FilterStore from persistence", it.url, it.cache.size)
                    emit(TunnelEvents.FILTERS_CHANGED, it.cache)
                    store = it
                },
                failure = {
                    e("failed loading FilterStore from persistence", it)
                }
        )
    }

    fun save() {
        doSaveFilterStore(store).mapBoth(
                success = { v("saved FilterStore to persistence", store.cache.size, store.url) },
                failure = { e("failed saving FilterStore to persistence", it) }
        )
    }

    fun setUrl(url: String) {
        if (store.url != url) {
            store = store.copy(lastFetch = 0, url = url)
            v("changed FilterStore url", url)
        }
    }

    fun hasUrl() = store.url.isNotBlank()

    fun findBySource(source: String) : Filter?{
        return store.cache.find { it.source.id == "app" && it.source.source == source }
    }

    fun put(new: Filter) {
        val old = store.cache.firstOrNull { it == new }
        store = if (old == null) {
            v("adding filter", new.id)
            val lastPriority = store.cache.maxBy { it.priority }?.priority ?: 0
            store.copy(cache = store.cache.plus(new.copy(priority = lastPriority + 1)))
        } else {
            v("updating filter", new.id)
            val newWithPreservedFields = new.copy(
                    whitelist = old.whitelist,
                    priority = old.priority,
                    lastFetch = old.lastFetch
            )
            store.copy(cache = store.cache.minus(old).plus(newWithPreservedFields))
        }
        emit(TunnelEvents.FILTERS_CHANGED, store.cache)
    }

    fun remove(old: Filter) {
        v("removing filter", old.id)
        store = store.copy(cache = store.cache.minus(old))
        emit(TunnelEvents.FILTERS_CHANGED, store.cache)
    }

    fun removeAll() {
        v("removing all filters")
        store = store.copy(cache = emptySet())
        emit(TunnelEvents.FILTERS_CHANGED, store.cache)
    }

    fun invalidateCache() {
        v("invalidating filters cache")
        val invalidatedFilters = store.cache.map { it.copy(lastFetch = 0) }.toSet()
        store = store.copy(cache = invalidatedFilters, lastFetch = 0)
    }

    fun getWhitelistedApps() = {
        store.cache.filter { it.whitelist && it.active && it.source.id == "app" }.map {
            it.source.source
        }
    }()

    fun sync() = {
        if (syncFiltersWithRepo()) {
            val success = syncRules()
            emit(TunnelEvents.MEMORY_CAPACITY, Memory.linesAvailable())
            success
        } else false
    }()

    private fun syncFiltersWithRepo(): Boolean {
        if (store.url.isEmpty()) {
            w("trying to sync without url set, ignoring")
            return false
        }

        if (!doValidateFilterStoreCache(store)) {
            v("syncing filters", store.url)
            emit(TunnelEvents.FILTERS_CHANGING)
            doFetchFiltersFromRepo(store.url).mapBoth(
                    success = { builtinFilters ->
                        v("fetched. size:", builtinFilters.size)

                        val new = if (store.cache.isEmpty()) {
                            v("no local filters found, setting default configuration")
                            builtinFilters
                        } else {
                            v("combining with existing filters")
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
                        v("synced", store.cache.size)
                        emit(TunnelEvents.FILTERS_CHANGED, store.cache)
                    },
                    failure = {
                        e("failed syncing filters", it)
                    }
            )
        }

        return true
    }

    private fun syncRules() = {
        val active = store.cache.filter { it.active }
        val downloaded = mutableSetOf<Filter>()
        active.forEach { filter ->
            if (!doValidateRulesetCache(filter)) {
                v("fetching ruleset", filter.id)
                emit(TunnelEvents.FILTERS_CHANGING)
                doFetchRuleset(doResolveFilterSource(filter), doGetMemoryLimit()).mapBoth(
                        success = {
                            blockade.set(filter.id, it)
                            downloaded.add(filter.copy(lastFetch = System.currentTimeMillis()))
                            v("saved", filter.id, it.size)
                        },
                        failure = {
                            e("failed fetching ruleset", filter.id, it)
                        }
                )
            }
        }

        store = store.copy(cache = store.cache - downloaded + downloaded)

        val allowed = store.cache.filter { it.whitelist && it.active }.map { it.id }
        val denied = store.cache.filter { !it.whitelist && it.active }.map { it.id }

        v("attempting to build rules, denied/allowed", denied.size, allowed.size)
        blockade.build(denied, allowed)
        allowed.size > 0 || denied.size > 0
    }()

}
