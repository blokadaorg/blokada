package core

import android.util.Log
import filter.FilterSerializer
import filter.FilterSourceDescriptor
import gs.environment.load
import gs.environment.openUrl
import gs.property.I18n
import io.paperdb.Paper
import kotlinx.coroutines.experimental.*
import kotlinx.coroutines.experimental.channels.*
import java.io.InputStreamReader
import java.net.URL
import java.nio.charset.Charset
import java.util.*

var TEST = false

fun log(vararg msgs: Any) {
    if (TEST) {
        msgs.forEach { System.out.println(it.toString()) }
    } else {
        msgs.forEach { when(it) {
            is Exception -> Log.e("blokada", "------", it)
            else -> Log.e("blokada", it.toString())
        }}
    }
}

class Commands(
        private val filters: SendChannel<Cmd>,
        private val localisations: SendChannel<Cmd>
) {

    fun <T> one(cmd: Monitor<T>) = runBlocking {
        val actor = decide(cmd)
        actor.send(cmd)
        val channel = cmd.deferred.await()
        val result = channel.receive()
        actor.send(CloseMonitor(channel))
        result
    }

    fun <T> channel(cmd: Monitor<T>) = runBlocking {
        val actor = decide(cmd)
        actor.send(cmd)
        cmd.deferred.await()
    }

    fun send(cmd: Cmd) = launch {
        decide(cmd).send(cmd)
    }

    private fun decide(cmd: Cmd): SendChannel<Cmd> {
        return when (cmd) {
            is LoadFilters, is SaveFilters, is UpdateFilter, is SyncFilters, is SyncHostsCache, is MonitorFilters,
                    is MonitorHostsCache, is MonitorHostsCount, is DeleteAllFilters,
                    is InvalidateAllFiltersCache -> filters
            is SyncTranslations -> localisations
            else -> throw Exception("unknown command $cmd")
        }
    }
}

sealed class Cmd

abstract class Monitor<T>(
        val deferred: CompletableDeferred<ReceiveChannel<T>> = CompletableDeferred()
) : Cmd()

internal class Notify<out T>(val value: T) : Cmd()
internal class CloseMonitor<T>(val channel: ReceiveChannel<T>) : Cmd()

fun <T> monitorActor(init: T) = actor<Cmd> {

    val notifyQueue = Channel<T>()
    var monitors = emptySet<Channel<T>>()
    var lastValue: T = init

    launch {
        for (v in notifyQueue) {
            monitors.forEach { launch {
                try {
                    it.send(v)
                } catch (e: Exception) {
                    channel.send(CloseMonitor(it))
                }
            }}
        }
    }

    for (msg in channel) {
        when (msg) {
            is Monitor<*> -> {
                val c = Channel<T>()
                try {
                    monitors += c
                    msg as Monitor<T>
                    msg.deferred.complete(c)
                    c.send(lastValue)
                } catch (e: Exception) {
                    monitors -= c
                    msg.deferred.completeExceptionally(e)
                }
            }
            is CloseMonitor<*> -> {
                monitors.first { it == msg.channel }.close()
                monitors -= msg.channel as Channel<T>
            }
            is Notify<*> -> {
                msg as Notify<T>
                lastValue = msg.value
                notifyQueue.send(lastValue)
            }
        }
    }
}

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

fun silent(exec: () -> Unit) {
    try {
        exec()
    } catch (e: Exception) {}
}

fun filtersActor(
        url: () -> URL,
        legacyCache: () -> List<String> = { emptyList() },
        loadFilters: () -> FiltersCache = {
            // First, check legacy persistence and see if it contains anything
            try {
                val old = FilterSerializer().deserialise(legacyCache())
                if (old.isNotEmpty()) {
                    // Found legacy persistence. Use it. Assume it's deleted on first access.
                    FiltersCache(old, fetchTimeMillis = 0)
                } else throw Exception("no legacy")
            } catch (e: Exception) {
                // No legacy. Use the new and fancy.
                Paper.book().read<FiltersCache>("filters2", FiltersCache(fetchTimeMillis = 0))
            }
        },
        saveFilters: (FiltersCache) -> Unit = { Paper.book().write("filters2", it) },
        loadHosts: () -> Set<HostsCache> = { Paper.book().read<Set<HostsCache>>("hosts2", emptySet()) },
        saveHosts: (Set<HostsCache>) -> Unit = { Paper.book().write("hosts2", it) },
        downloadFilters: () -> Set<Filter> = { runBlocking {
            val serializer = FilterSerializer()
            try {
                    serializer.deserialise(load({ openUrl(url(), 10 * 1000) }))
                } catch (e: Exception) {
                    // Try one more time in case it was a ephemeral problem
                    delay(3000)
                    try {
                        serializer.deserialise(load({ openUrl(url(), 10 * 1000) }))
                    } catch (e: Exception) {
                        log("sync filters: failed to download filters after second try", e)
                        emptySet<Filter>()
                    }
                }
        }},
        processDownloadedFilters: (Set<Filter>) -> Set<Filter> = { it },
        getSource: (FilterSourceDescriptor, FilterId) -> IFilterSource,
        isCacheValid: (HostsCache) -> Boolean = { false },
        isFiltersCacheValid: (FiltersCache, URL) -> Boolean = { cache, url -> false }
) = actor<Cmd> {

    var filters = FiltersCache(fetchTimeMillis = 0)
    var hosts = mapOf<FilterId, HostsCache>()
    var combinedHosts = emptySet<String>()

    val filtersSync = monitorActor<Set<Filter>>(emptySet())
    val cacheSync = monitorActor<Set<String>>(emptySet())
    val hostsCountSync = monitorActor(0)

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
        log("combining cache")
        combinedHosts = getActiveFiltersCache(false).flatMap { it.cache }.minus(
                getActiveFiltersCache(true).flatMap { it.cache }
        ).toSet()
    }

    for (cmd in channel) {
        when (cmd) {
            is LoadFilters -> {
                filters = loadFilters()

                hosts = emptyMap()
                loadHosts().forEach { hosts += it.id to it }
                filters.cache.filter { !hosts.containsKey(it.id) }.forEach {
                    hosts += it.id to HostsCache(it.id)
                }

                filtersSync.send(Notify(filters.cache))
                combineCache()
                cacheSync.send(Notify(combinedHosts))
                hostsCountSync.send(Notify(combinedHosts.size))
                log("persistence loaded")
            }
            is SaveFilters -> {
                saveFilters(FiltersCache(filters.cache, url = filters.url))
                saveHosts(hosts.values.toSet())
                log("persistence saved")
            }
            is SyncFilters -> {
                if (!isFiltersCacheValid(filters, url())) {
                    log("sync filters download: ${url()}")

                    val builtinFilters = processDownloadedFilters(downloadFilters())
                    log("sync filters: combine")
                    val newFilters = if (filters.cache.isEmpty()) {
                        // First preselect
                        builtinFilters
                    } else {
                        // Update existing filters just in case
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
                } else log("no need to sync filters, up to date")

                filtersSync.send(Notify(filters.cache))
                log("sync filters done")
            }
            is SyncHostsCache -> {
                download(selectInvalidCache(getActiveFiltersCache(null)).mapNotNull {
                    try {
                        it to getSource(filters.cache.first { that -> it.id == that.id }.source, it.id)
                    } catch (e: Exception) {
                        null
                    }
                }.asReceiveChannel()).consumeEach {
                    hosts += it.id to HostsCache(it.id, it.cache)
                }

                combineCache()
                cacheSync.send(Notify(combinedHosts))
                hostsCountSync.send(Notify(combinedHosts.size))
                log("sync cache done")
            }
            is UpdateFilter -> {
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
                                    newCustomComment = cmd.filter.customComment ?: old.customComment
                            )
                        }
                        else -> filters += cmd.filter
                    }
                    if (!hosts.containsKey(cmd.id)) {
                        hosts += cmd.id to HostsCache(cmd.id)
                    }
                }
                filtersSync.send(Notify(filters.cache))
                log("update filter done")
            }
            is DeleteAllFilters -> {
                filters = FiltersCache(fetchTimeMillis = 0)
                log("deleted all filters")
            }
            is InvalidateAllFiltersCache -> {
                filters = FiltersCache(filters.cache, fetchTimeMillis = 0)
                hosts = emptyMap()
                log("invalidated all filters cache")
            }
            is MonitorHostsCache -> {
                cacheSync.send(cmd)
            }
            is MonitorFilters -> {
                filtersSync.send(cmd)
            }
            is MonitorHostsCount -> {
                hostsCountSync.send(cmd)
            }
        }
    }
}

private fun download(filters: ReceiveChannel<Pair<HostsCache, IFilterSource>>) = produce {
    var jobs = emptyList<Job>()
    filters.consumeEach {
        jobs += launch {
            val id = it.first.id
            val source = it.second
            log("downloading $id")
            val hosts = source.fetch()
            send(HostsCache(id, hosts.toSet()))
            log("finished $id")
        }
    }
    jobs.forEach { it.join() }
}

class SyncTranslations : Cmd()

typealias Prefix = String
typealias Key = String
typealias Translation = String

fun localisationActor(
        urls: () -> Map<URL, Prefix>,
        load: () -> TranslationsCacheInfo = { Paper.book().read("translationsCacheInfo", TranslationsCacheInfo()) },
        save: (TranslationsCacheInfo) -> Unit = { Paper.book().write("translationsCacheInfo", it) },
        cacheValid: (TranslationsCacheInfo, URL) -> Boolean = { _, _ -> false },
        downloadTranslations: (Map<URL, Prefix>) -> ReceiveChannel<Pair<URL, List<Pair<Key, Translation>>>> = { urls ->
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
                            log("sync filters: fail fetch localisation", e)
                            send(url to emptyList<Pair<Key, Translation>>())
                        }
                    }
                }
                jobs.forEach { it.join() }
            }
        },
        i18n: I18n
) = actor<Cmd> {

    var info: TranslationsCacheInfo

    for (cmd in channel) {
        when (cmd) {
            is SyncTranslations -> {
                info = load()
                val invalid = urls().filter { !cacheValid(info, it.key) }
                downloadTranslations(invalid).consumeEach {
                    val (url, result) = it
                    if (result.isNotEmpty()) {
                        result.forEach { translation ->
                            i18n.set(translation.first, translation.second)
                        }
                        info = info.put(url)
                    }
                }
                save(info)
                log("filter localisations sync done")
            }
        }
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
