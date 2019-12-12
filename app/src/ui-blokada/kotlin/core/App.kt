package core

import android.app.Activity
import android.content.Context
import com.github.salomonbrys.kodein.*
import filter.DefaultSourceProvider
import gs.environment.ComponentProvider
import gs.environment.Environment
import gs.environment.Worker
import gs.presentation.ViewBinderHolder
import gs.property.*
import kotlinx.coroutines.experimental.launch
import org.blokada.BuildConfig
import org.blokada.R

abstract class UiState {

    abstract val seenWelcome: IProperty<Boolean>
    abstract val notifications: IProperty<Boolean>
    abstract val showSystemApps: IProperty<Boolean>
    abstract val showBgAnim: IProperty<Boolean>
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
            { false } // By default, have notifications off. 
    )

    override val showSystemApps = newPersistedProperty(kctx, APrefsPersistence(ctx, "showSystemApps"),
            { true }
    )

    override val showBgAnim = newPersistedProperty(kctx, APrefsPersistence(ctx, "backgroundAnimation"),
            { true }
    )
}

fun newAppModule(ctx: Context): Kodein.Module {
    return Kodein.Module {
        bind<EnabledStateActor>() with singleton {
            EnabledStateActor(this.lazy)
        }
        bind<UiState>() with singleton { AUiState(kctx = with("gscore").instance(10), xx = lazy) }
        bind<ComponentProvider<Activity>>() with singleton { ComponentProvider<Activity>() }
        bind<DefaultSourceProvider>() with singleton {
            DefaultSourceProvider(ctx = instance(), processor = instance(),
                    repo = instance(), f = instance())
        }
        bind<g11n.Main>() with singleton {
            val pages: Pages = instance()
            val i18n: I18n = instance()
            g11n.Main(
                    urls = { mapOf(
                            pages.filtersStringsFallback().toExternalForm() to "filters",
                            pages.filtersStrings().toExternalForm() to "filters"
                    ) },
                    doPutTranslation = { key, value ->
                        core.Result.of { i18n.set(key, value); true }
                    }
            )
        }
        bind<ViewBinderHolder>() with singleton {
            ViewBinderHolder()
        }

        onReady {
            val d: Device = instance()
            val repo: Repo = instance()
            val g11: g11n.Main = instance()

            launch {
                g11.load("translations:firstLoad".ktx())

                val ktx = ctx.ktx("translations:sync:filters")
                ktx.on(tunnel.TunnelEvents.FILTERS_CHANGED) {
                    g11.sync(ktx)
                }
            }

            val i18n: I18n = instance()
            i18n.locale.doWhenChanged().then {
                "app:onLocaleSet".ktx().v("refresh filters on locale set")
                g11.sync("translations:sync:locale".ktx())
            }

            // Since having filters is really important, poke whenever we get connectivity
            var wasConnected = false
            d.connected.doWhenChanged().then {
                if (d.connected() && !wasConnected) {
                    entrypoint.onWentOnline()
                }
                wasConnected = d.connected()
            }

            val version: Version = instance()
            version.appName %= ctx.getString(R.string.branding_app_name)

            val p = BuildConfig.VERSION_NAME.split('.')
            version.name %= if (p.size == 3) "%s.%s (%s)".format(p[0], p[1], p[2])
            else BuildConfig.VERSION_NAME

            version.name %= version.name() + " " + BuildConfig.BUILD_TYPE.capitalize()

            // This will fetch repo unless already cached
            repo.url %= "https://blokada.org/api/v4/${BuildConfig.FLAVOR}/${BuildConfig.BUILD_TYPE}/repo.txt"
        }
    }
}

class APrefsPersistence<T>(
        val ctx: Context,
        val key: String
) : gs.property.Persistence<T> {

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
