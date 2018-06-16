package core

import android.util.Log
import filter.FilterSerializer
import filter.FilterSourceDescriptor
import gs.environment.load
import gs.environment.openUrl
import io.paperdb.Paper
import kotlinx.coroutines.experimental.*
import kotlinx.coroutines.experimental.channels.*
import java.io.InputStreamReader
import java.net.URL
import java.nio.charset.Charset
import java.util.*
import kotlin.coroutines.experimental.CoroutineContext
import kotlin.reflect.KClass

var LOG_TEST = false
val LOG_DEFAULT_TAG = "b3"
val LOG_ERROR = 6
val LOG_WARNING = 5
val LOG_VERBOSE = 2

val CONTEXT_WATCHDOG = newSingleThreadContext("watchdog")

private fun log(priority: Int, tag: String, vararg msgs: Any) {
    val params = msgs.drop(1).map { it.toString() }
            .plus(tag)
            .plus(Thread.currentThread())
            .joinToString(", ")
    val msg = if (msgs[0] is Cmd) msgs[0].javaClass.canonicalName else msgs[0]
    if (LOG_TEST) {
        val out = if (priority == LOG_ERROR) System.err else System.out
        out.println("b3:${msgs[0].hashCode()}${indent(priority, tag)}$msg ($params)")
        if (priority != LOG_VERBOSE) {
            msgs.filter { it is Throwable }.forEach {
                (it as Throwable).printStackTrace(out)
            }
        }
    } else {
        Log.println(priority, "b3:${msgs[0].hashCode()}", "${indent(priority, tag)}$msg ($params)")
        if (priority != LOG_VERBOSE) {
            msgs.filter { it is Throwable }.forEach {
                Log.println(priority, tag, Log.getStackTraceString(it as Throwable))
            }
        }
    }
}

private fun indent(priority: Int, tag: String, level: Int = 0): String {
    var indent = 1
    if (priority == LOG_VERBOSE) indent += 4
    if (tag == LOG_DEFAULT_TAG) indent += 7
    indent += 4 * level
    return " ".repeat(indent)
}

fun e(vararg msgs: Any) {
    log(LOG_ERROR, LOG_DEFAULT_TAG, *msgs)
}

fun w(vararg msgs: Any) {
    log(LOG_WARNING, LOG_DEFAULT_TAG, *msgs)
}

fun v(vararg msgs: Any) {
    log(LOG_VERBOSE, LOG_DEFAULT_TAG, *msgs)
}

fun Commands.e(vararg msgs: Any) {
    log(LOG_ERROR, "$LOG_DEFAULT_TAG.cmd", *msgs)
}

fun Commands.w(vararg msgs: Any) {
    log(LOG_WARNING, "$LOG_DEFAULT_TAG.cmd", *msgs)
}

fun Commands.v(vararg msgs: Any) {
    log(LOG_VERBOSE, "$LOG_DEFAULT_TAG.cmd", *msgs)
}

fun CommandsActor.v(vararg msgs: Any) {
    log(LOG_VERBOSE, "$LOG_DEFAULT_TAG.a.${javaClass.canonicalName}", *msgs)
}

fun CommandsActor.w(vararg msgs: Any) {
    log(LOG_WARNING, "$LOG_DEFAULT_TAG.a.${javaClass.canonicalName}", *msgs)
}

fun CommandsActor.e(vararg msgs: Any) {
    log(LOG_ERROR, "$LOG_DEFAULT_TAG.a.${javaClass.canonicalName}", *msgs)
}

class Commands(
        private val filters: SendChannel<Cmd>,
        private val localisations: LocalisationActor,
        private val hostsCountSync: BroadcastChannel<Int>,
        private val filtersMonitor: BroadcastChannel<Set<Filter>>,
        private val cacheMonitor: BroadcastChannel<Set<String>>
) {

    fun <T> one(cmd: Monitor<T>) = runBlocking {
        val monitor = decideMonitor(cmd)
        val sub = monitor.openSubscription()
        val current = sub.receive()
        sub.cancel()
        current
    }

    fun <T> subscribe(cmd: Monitor<T>) = runBlocking {
        val monitor = decideMonitor(cmd)
        v(cmd, "subscribe", monitor)
        monitor.openSubscription()
    }

    fun send(cmd: Cmd) = launch {
        decide(cmd).send(cmd)
    }

    val loc by lazy { localisations.create() }

    private fun decide(cmd: Cmd): SendChannel<Cmd> {
        return when (cmd) {
            is LoadFilters, is SaveFilters, is UpdateFilter, is SyncFilters, is SyncHostsCache,
                    is DeleteAllFilters, is InvalidateAllFiltersCache -> filters
            is SyncTranslations -> loc
            else -> throw Exception("unknown command $cmd")
        }
    }

    private fun <T> decideMonitor(cmd: Monitor<T>): BroadcastChannel<T> {
        return when (cmd) {
            is MonitorHostsCount -> hostsCountSync as BroadcastChannel<T>
            is MonitorFilters -> filtersMonitor as BroadcastChannel<T>
            is MonitorHostsCache -> cacheMonitor as BroadcastChannel<T>
            else -> throw Exception("unknown monitor $cmd")
        }
    }
}

sealed class Cmd

abstract class Monitor<T>(
        val deferred: CompletableDeferred<ReceiveChannel<T>> = CompletableDeferred()
) : Cmd()

typealias FilterId = String

data class Filter(
        val id: FilterId,
        val source: FilterSourceDescriptor,
        val whitelist: Boolean = false,
        val active: Boolean = false,
        val hidden: Boolean = false,
        val priority: Int = 0,
        val credit: String? = null,
        val customName: String? = null,
        val customComment: String? = null
) {
    fun alter(
            newActive: Boolean = active,
            newHidden: Boolean = hidden,
            newPriority: Int = priority,
            newCredit: String? = credit,
            newCustomName: String? = customName,
            newCustomComment: String? = customComment
    ): Filter {
        return Filter(id, source, whitelist, newActive, newHidden, newPriority, newCredit, newCustomName,
                newCustomComment)
    }

    override fun hashCode(): Int {
        return id.hashCode()
    }

    override fun equals(other: Any?): Boolean {
        if (other !is Filter) return false
        return id.equals(other.id)
    }
}

data class HostsCache(
        val id: FilterId,
        val cache: Set<String> = emptySet(),
        val fetchTimeMillis: Long = System.currentTimeMillis()
)

data class FiltersCache(
        val cache: Set<Filter> = emptySet(),
        val fetchTimeMillis: Long = System.currentTimeMillis(),
        val url: String = ""
) {
    operator fun minus(filter: Filter): FiltersCache {
        return FiltersCache(cache.minus(filter), fetchTimeMillis, url)
    }

    operator fun plus(filter: Filter): FiltersCache {
        return FiltersCache(cache.minus(filter).plus(filter), fetchTimeMillis, url)
    }
}

class LoadFilters : Cmd()
class SaveFilters : Cmd()
class SyncFilters : Cmd()
class SyncHostsCache : Cmd()
class MonitorHostsCache : Monitor<Set<String>>()
class MonitorFilters : Monitor<Set<Filter>>()
class MonitorHostsCount : Monitor<Int>()
class UpdateFilter(val id: FilterId, val filter: Filter?) : Cmd()
class DeleteAllFilters : Cmd()
class InvalidateAllFiltersCache : Cmd()

val HOST_COUNT_UPDATING = -1

fun silent(exec: () -> Unit) {
    try {
        exec()
    } catch (e: Exception) {}
}

class FiltersActor(
        val url: () -> URL,
        val legacyCache: () -> List<String> = { emptyList() },
        val loadFilters: () -> FiltersCache = {
            // First, check legacy persistence and see if it contains anything
            try {
                val leg = legacyCache()
                val old = FilterSerializer().deserialise(leg)
                if (old.isNotEmpty()) {
                    // Found legacy persistence. Use it. Assume it's deleted on first access.
                    v("loaded from legacy persistence", old.size)
                    FiltersCache(old, fetchTimeMillis = 0)
                } else throw Exception("no legacy")
            } catch (e: Exception) {
                // No legacy. Use the new and fancy.
                v("loading from the new persistence")
                Paper.book().read<FiltersCache>("filters2", FiltersCache(fetchTimeMillis = 0))
            }
        },
        val saveFilters: (FiltersCache) -> Unit = { Paper.book().write("filters2", it) },
        val loadHosts: () -> Set<HostsCache> = { Paper.book().read<Set<HostsCache>>("hosts2", emptySet()) },
        val saveHosts: (Set<HostsCache>) -> Unit = { Paper.book().write("hosts2", it) },
        val downloadFilters: () -> Set<Filter> = { runBlocking {
            val serializer = FilterSerializer()
            try {
                    serializer.deserialise(load({ openUrl(url(), 10 * 1000) }))
                } catch (e: Exception) {
                    // Try one more time in case it was a ephemeral problem
                    delay(3000)
                    try {
                        serializer.deserialise(load({ openUrl(url(), 10 * 1000) }))
                    } catch (e: Exception) {
                        w("failed to download filters after second try", e)
                        emptySet<Filter>()
                    }
                }
        }},
        val processDownloadedFilters: (Set<Filter>) -> Set<Filter> = { it },
        val getSource: (FilterSourceDescriptor, FilterId) -> IFilterSource,
        val isCacheValid: (HostsCache) -> Boolean = { false },
        val isFiltersCacheValid: (FiltersCache, URL) -> Boolean = { cache, url -> false },
        val hostsCountSync: BroadcastChannel<Int> = BroadcastChannel(Channel.CONFLATED),
        val filtersSync: BroadcastChannel<Set<Filter>> = BroadcastChannel(Channel.CONFLATED),
        val cacheSync: BroadcastChannel<Set<String>> = BroadcastChannel(Channel.CONFLATED)
): CommandsActor() {

    override fun mapping(): Map<KClass<out Cmd>, (Cmd) -> Unit> { return mapOf(
            LoadFilters::class to ::load,
            SaveFilters::class to ::save,
            SyncFilters::class to ::syncFilters,
            SyncHostsCache::class to ::syncHostsCache,
            UpdateFilter::class to ::updateFilter,
            DeleteAllFilters::class to ::deleteAllFilters,
            InvalidateAllFiltersCache::class to ::invalidateAllFiltersCache
    )}

    var filters = FiltersCache(fetchTimeMillis = 0)
    var hosts = mapOf<FilterId, HostsCache>()
    var combinedHosts = emptySet<String>()


    val getActiveFiltersCache = { whitelist: Boolean? ->
        filters.cache.filter {
            it.active &&
                    (whitelist == null || it.whitelist == whitelist)
        }.map {
            hosts[it.id]
        }.filterNotNull()
    }

    val selectInvalidCache = { hosts: List<HostsCache> ->
        hosts.filter { !isCacheValid(it) }
    }

    val combineCache = {
        v("combining cache")
        combinedHosts = getActiveFiltersCache(false).flatMap { it.cache }.minus(
                getActiveFiltersCache(true).flatMap { it.cache }
        ).toSet()
    }

    private fun load(cmd: Cmd) = runBlocking {
        filters = loadFilters()
        v("loaded persistence")

        hosts = emptyMap()
        loadHosts().forEach { hosts += it.id to it }
        filters.cache.filter { !hosts.containsKey(it.id) }.forEach {
            hosts += it.id to HostsCache(it.id)
        }

        v("updated memory, notifying monitors")
        filtersSync.send(filters.cache)
        combineCache()
        cacheSync.send(combinedHosts)
        hostsCountSync.send(combinedHosts.size)
    }

    private fun save(cmd: Cmd) {
        saveFilters(FiltersCache(filters.cache, url = filters.url))
        saveHosts(hosts.values.toSet())
    }

    private fun syncFilters(cmd: Cmd) = runBlocking {
        if (!isFiltersCacheValid(filters, url())) {
            v(cmd, "download", url())

            val builtinFilters = processDownloadedFilters(downloadFilters())
            val newFilters = if (filters.cache.isEmpty()) {
                v(cmd, "first preselect")
                builtinFilters
            } else {
                v(cmd, "combine with existing filters")
                filters.cache.map { existing ->
                    val newFilter = builtinFilters.find { it == existing }
                    if (newFilter != null) {
                        newFilter.alter(
                                newActive = existing.active,
                                newHidden = existing.hidden,
                                newPriority = existing.priority
                        )
                    } else existing
                }.plus(builtinFilters.minus(filters.cache))
            }
            filters = FiltersCache(newFilters.toSet(), url = url().toExternalForm())
            filters.cache.filter { !hosts.containsKey(it.id) }.forEach {
                hosts += it.id to HostsCache(it.id)
            }
        } else v(cmd, "no need to sync filters, up to date")

        v(cmd, "before filter sync")
        filtersSync.send(filters.cache)
        v(cmd, "after filter sync")
    }

    private fun syncHostsCache(cmd: Cmd) = runBlocking {
        hostsCountSync.send(HOST_COUNT_UPDATING)
        val d = download(selectInvalidCache(getActiveFiltersCache(null)).mapNotNull {
            try {
                it to getSource(filters.cache.first { that -> it.id == that.id }.source, it.id)
            } catch (e: Exception) {
                null
            }
        })
        d.consumeEach {
            hosts += it.id to HostsCache(it.id, it.cache)
        }

        combineCache()
        cacheSync.send(combinedHosts)
        hostsCountSync.send(combinedHosts.size)
    }

    fun updateFilter(cmd: Cmd) = runBlocking {
        cmd as UpdateFilter
        if (cmd.filter == null) filters -= filters.cache.first { it.id == cmd.id }
        else {
            val old = filters.cache.firstOrNull { it.id == cmd.id }
            when {
                old == null -> filters += cmd.filter.alter(
                        newPriority = filters.cache.map { it.priority }.sorted().last() + 1
                )
                old.customName != null && cmd.filter.customName == null ||
                        old.customComment != null && cmd.filter.customComment == null -> {
                    filters += cmd.filter.alter(
                            newCustomName = cmd.filter.customName ?: old.customName,
                            newCustomComment = cmd.filter.customComment ?: old.customComment,
                            newPriority = old.priority
                    )
                }
                else -> filters += cmd.filter.alter(
                        newPriority = old.priority
                )
            }
            if (!hosts.containsKey(cmd.id)) {
                hosts += cmd.id to HostsCache(cmd.id)
            }
        }
        filtersSync.send(filters.cache)
    }

    fun deleteAllFilters(cmd: Cmd) {
        filters = FiltersCache(fetchTimeMillis = 0)
    }

    fun invalidateAllFiltersCache(cmd: Cmd) {
        filters = FiltersCache(filters.cache, fetchTimeMillis = 0)
        hosts = emptyMap()
    }

    private fun download(filters: List<Pair<HostsCache, IFilterSource>>) = produce {
        var jobs = emptyList<Job>()
        filters.forEach {
            jobs += launch {
                val id = it.first.id
                val source = it.second
                try {
                    v("download filters: processing", id)
                    val hosts = source.fetch()
                    send(HostsCache(id, hosts.toSet()))
                    v("download filters: finished", id)
                } catch (e: Exception) {
                    w("download filters: fail", id, e)
                }
            }
        }
        jobs.forEach { it.join() }
    }
}

class SyncTranslations : Cmd()

typealias Prefix = String
typealias Key = String
typealias Translation = String

abstract class CommandsActor {

    abstract fun mapping(): Map<KClass<out Cmd>, (Cmd) -> Unit>

    val block: suspend ActorScope<Cmd>.() -> Unit = {
        val map = mapping()
        for (cmd in channel) {
            if (map.containsKey(cmd::class)) {
                val watchdogJob = launch(CONTEXT_WATCHDOG) {
                    delay(5000)
                    e(cmd, "slow")
                }
                try {
                    v(cmd, "start")
                    map[cmd::class]?.invoke(cmd)
                    v(cmd, "finished")
                    watchdogJob.cancel()
                } catch (e: Exception) {
                    e(cmd, "exception", e)
                    watchdogJob.cancel()
                }
            } else {
                w(cmd, "unknown")
            }
        }
    }

    fun create(): SendChannel<Cmd> {
        val newContext = newCoroutineContext(DefaultDispatcher, parent = null)
        val channel = Channel<Cmd>(capacity = 0)
        val coroutine = ActorCoroutine(newContext, channel, active = true)
        coroutine.start(CoroutineStart.DEFAULT, coroutine, block)
        return coroutine
    }
}

class LocalisationActor(
        val urls: () -> Map<URL, Prefix>,
        val load: () -> TranslationsCacheInfo = { Paper.book().read("translationsCacheInfo", TranslationsCacheInfo()) },
        val save: (TranslationsCacheInfo) -> Unit = { Paper.book().write("translationsCacheInfo", it) },
        val cacheValid: (TranslationsCacheInfo, URL) -> Boolean = { _, _ -> false },
        val downloadTranslations: (Map<URL, Prefix>) -> ReceiveChannel<Pair<URL, List<Pair<Key, Translation>>>> = { urls ->
            produce {
                var jobs: Set<Job> = emptySet()
                urls.forEach { (url, prefix) ->
                    jobs += launch {
                        try {
                            val prop = Properties()
                            prop.load(InputStreamReader(
                                    openUrl(url, 10 * 1000), Charset.forName("UTF-8")))
                            val res = url to prop.stringPropertyNames().map { key ->
                                "${prefix}_$key" to prop.getProperty(key) }
                            send(res)
                        } catch (e: Exception) {
                            e("fail fetch localisation", e)
                            send(url to emptyList())
                        }
                    }
                }
                jobs.forEach { it.join() }
            }
        },
        val setI18n: (key: String, value: String) -> Unit = { _, _ -> }
): CommandsActor() {

    override fun mapping(): Map<KClass<out Cmd>, (Cmd) -> Unit> { return mapOf(
            SyncTranslations::class to ::sync
    )}

    private var info = TranslationsCacheInfo()

    private fun sync(cmd: Cmd) = runBlocking {
        info = load()
        v("loaded persistence")
        val invalid = urls().filter { !cacheValid(info, it.key) }
        downloadTranslations(invalid).consumeEach {
            val (url, result) = it
            if (result.isNotEmpty()) {
                result.forEach { translation ->
                    setI18n(translation.first, translation.second)
                }
                info = info.put(url)
            }
        }
        v("downloaded all translations")
        save(info)
        v("saved persistence")
    }
}

data class TranslationsCacheInfo(
        private val info: Map<URL, Long> = emptyMap()
) {
    fun get(url: URL): Long {
        return info.getOrElse(url, { 0 })
    }
    fun put(url: URL): TranslationsCacheInfo {
        return TranslationsCacheInfo(info.plus(url to System.currentTimeMillis()))
    }
}

internal open class ChannelCoroutine<E>(
        parentContext: CoroutineContext,
        protected val _channel: Channel<E>,
        active: Boolean
) : AbstractCoroutine<Unit>(parentContext, active), Channel<E> by _channel {
    val channel: Channel<E>
        get() = this

    // Workaround for KT-23094
    override suspend fun receive(): E = _channel.receive()

    override suspend fun send(element: E) = _channel.send(element)

    override suspend fun receiveOrNull(): E? = _channel.receiveOrNull()

    override fun cancel(cause: Throwable?): Boolean = super.cancel(cause)
}

private open class ActorCoroutine<E>(
        parentContext: CoroutineContext,
        channel: Channel<E>,
        active: Boolean
) : ChannelCoroutine<E>(parentContext, channel, active), ActorScope<E>, ActorJob<E> {
    override fun onCancellation(cause: Throwable?) {
        _channel.cancel(cause)
        // Always propagate the exception, don't wait for actor senders
        if (cause != null) handleCoroutineException(context, cause)
    }
}

