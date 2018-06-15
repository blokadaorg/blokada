package core

import android.app.Activity
import android.content.Context
import com.github.salomonbrys.kodein.*
import filter.DefaultSourceProvider
import gs.environment.*
import gs.property.*
import kotlinx.coroutines.experimental.channels.BroadcastChannel
import kotlinx.coroutines.experimental.channels.Channel
import kotlinx.coroutines.experimental.channels.ReceiveChannel
import kotlinx.coroutines.experimental.channels.consumeEach
import kotlinx.coroutines.experimental.launch
import kotlinx.coroutines.experimental.runBlocking
import org.blokada.BuildConfig
import org.blokada.R

abstract class UiState {

    abstract val seenWelcome: IProperty<Boolean>
    abstract val notifications: IProperty<Boolean>
    abstract val dashes: IProperty<List<Dash>>
    abstract val infoQueue: IProperty<List<Info>>
    abstract val showSystemApps: IProperty<Boolean>
}

class AUiState(
        private val kctx: Worker,
        private val xx: Environment
) : UiState() {

    private val ctx: Context by xx.instance()

    override val seenWelcome = newPersistedProperty(kctx, APrefsPersistence(ctx, "seenWelcome"),
            { false }
    )

    override val notifications = newPersistedProperty(kctx, APrefsPersistence(ctx, "notifications"),
            { true }
    )

    override val dashes = newPersistedProperty(kctx, ADashesPersistence(ctx), { ctx.inject().instance() })

    override val infoQueue = newProperty(kctx, { listOf<Info>() })

    override val showSystemApps = newPersistedProperty(kctx, APrefsPersistence(ctx, "showSystemApps"),
            { true })

}

fun logChannel(name: String, c: ReceiveChannel<Any>, j: Journal) = launch {
    c.consumeEach { value ->
        when {
            value is Exception -> {
                j.log("$name: $value", value)
            }
            else -> {
                j.log("$name: $value")
            }
        }
    }
}

fun newAppModule(ctx: Context): Kodein.Module {
    return Kodein.Module {
        bind<EnabledStateActor>() with singleton {
            EnabledStateActor(this.lazy)
        }
        bind<UiState>() with singleton { AUiState(kctx = with("gscore").instance(10), xx = lazy) }
        bind<ComponentProvider<Activity>>() with singleton { ComponentProvider<Activity>() }
        bind<ComponentProvider<MainActivity>>() with singleton { ComponentProvider<MainActivity>() }
        bind<DefaultSourceProvider>() with singleton {
            DefaultSourceProvider(ctx = instance(), j = instance(), processor = instance(),
                    repo = instance(), f = instance())
        }
        bind<Commands>() with singleton {
            val pages: Pages = instance()
            val source: DefaultSourceProvider = instance()
            val f: Filters = instance()

            val hostsCountSync = BroadcastChannel<Int>(Channel.CONFLATED)
            val filtersMonitor = BroadcastChannel<Set<Filter>>(Channel.CONFLATED)
            val cacheMonitor = BroadcastChannel<Set<String>>(Channel.CONFLATED)

            val filtersActor = FiltersActor(
                    url = { pages.filters() },
                    getSource = { descriptor, id -> source.from(descriptor.id, descriptor.source, id) },
                    isCacheValid = {
                        it.cache.isNotEmpty()
                                && it.fetchTimeMillis + 86400 * 1000 > System.currentTimeMillis()
                    },
                    legacyCache = {
                        val p = ctx.getSharedPreferences("filters", Context.MODE_PRIVATE)
                        val legacy = p.getString("filters", "").split("^")
                        p.edit().putString("filters", "").apply()
                        legacy
                    },
                    isFiltersCacheValid = { info, url ->
                        info.cache.isNotEmpty()
                                && info.url == url.toExternalForm()
                                && info.fetchTimeMillis + 86400 * 1000 > System.currentTimeMillis()
                    },
                    processDownloadedFilters = {
                        f.apps.refresh(blocking = true)
                        it.map {
                            when {
                                it.source.id != "app" -> it
                                f.apps().firstOrNull { a -> a.appId == it.source.source } == null -> {
                                    it.alter(newHidden = true, newActive = false)
                                }
                                else -> it
                            }
                        }.toSet()
                    },
                    hostsCountSync = hostsCountSync,
                    filtersSync = filtersMonitor,
                    cacheSync = cacheMonitor
            ).create()

            val localisationsActor = LocalisationActor(
                    urls = {
                        mapOf(
                                pages.filtersStrings() to "filters"
                        )
                    },
                    cacheValid = { info, url ->
                        info.get(url) + 86400 * 1000 > System.currentTimeMillis()
                    },
                    setI18n = { key, value ->
                        val i18n: I18n = instance()
                        i18n.set(key, value)
                    }
            )

            Commands(filtersActor, localisationsActor, hostsCountSync, filtersMonitor, cacheMonitor)
        }

        onReady {
            val d: Device = instance()
            val repo: Repo = instance()
            val f: Filters = instance()
            val cmd: Commands = instance()
            val j: Journal = instance()
            val pages: Pages = instance()

            // New code init
            runBlocking {
                cmd.send(LoadFilters())
            }

            launch {
                cmd.subscribe(MonitorHostsCount()).consumeEach {
                    // Todo: a nicer hook would be good to minimise unnecessary downloads
                    // Todo: dont sync all translations, just filters related
                    if (it != HOST_COUNT_UPDATING) {
                        cmd.send(SaveFilters())
                        cmd.send(SyncTranslations())
                    }
                }
            }

            // Since having filters is really important, poke whenever we get connectivity
            var wasConnected = false
            d.connected.doWhenChanged().then {
                if (d.connected() && !wasConnected) {
                    repo.content.refresh()
                    cmd.send(SyncFilters())
                    cmd.send(SyncHostsCache())
                }
                wasConnected = d.connected()
            }

            val version: Version = instance()
            version.appName %= ctx.getString(R.string.branding_app_name)

            val p = BuildConfig.VERSION_NAME.split('.')
            version.name %= if (p.size == 3) "%s.%s (%s)".format(p[0], p[1], p[2])
            else BuildConfig.VERSION_NAME

            version.name %= version.name() + " " + BuildConfig.BUILD_TYPE.capitalize()

            pages.filters.doWhenChanged(withInit = true).then {
                cmd.send(SyncFilters())
                cmd.send(SyncHostsCache())
            }

            // This will fetch repo unless already cached
            repo.url %= "https://blokada.org/api/v3/${BuildConfig.FLAVOR}/${BuildConfig.BUILD_TYPE}/repo.txt"
        }
    }
}

class APrefsPersistence<T>(
        val ctx: Context,
        val key: String
) : Persistence<T> {

    val p by lazy { ctx.getSharedPreferences("default", Context.MODE_PRIVATE) }

    override fun read(current: T): T {
        return when (current) {
            is Boolean -> p.getBoolean(key, current)
            is Int -> p.getInt(key, current)
            is Long -> p.getLong(key, current)
            is String -> p.getString(key, current)
            else -> throw Exception("unsupported type for ${key}")
        } as T
    }

    override fun write(source: T) {
        val e = p.edit()
        when(source) {
            is Boolean -> e.putBoolean(key, source)
            is Int -> e.putInt(key, source)
            is Long -> e.putLong(key, source)
            is String -> e.putString(key, source)
            else -> throw Exception("unsupported type for ${key}")
        }
        e.apply()
    }

}
