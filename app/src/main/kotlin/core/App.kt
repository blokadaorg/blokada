package core

import android.app.Activity
import android.content.Context
import com.github.salomonbrys.kodein.*
import gs.environment.ComponentProvider
import gs.environment.Environment
import gs.environment.Worker
import gs.environment.inject
import gs.property.*
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

fun newAppModule(ctx: Context): Kodein.Module {
    return Kodein.Module {
        bind<EnabledStateActor>() with singleton {
            EnabledStateActor(this.lazy)
        }
        bind<UiState>() with singleton { AUiState(kctx = with("gscore").instance(10), xx = lazy) }
        bind<ComponentProvider<Activity>>() with singleton { ComponentProvider<Activity>() }
        bind<ComponentProvider<MainActivity>>() with singleton { ComponentProvider<MainActivity>() }

        onReady {
            val d: Device = instance()
            val repo: Repo = instance()
            val f: Filters = instance()

            // Since having filters is really important, poke whenever we get connectivity
            var wasConnected = false
            d.connected.doWhenChanged().then {
                if (d.connected() && !wasConnected) {
                    repo.content.refresh()
                    f.filters.refresh()
                }
                wasConnected = d.connected()
            }

            val version: Version = instance()
            version.appName %= ctx.getString(R.string.branding_app_name)
            version.name %= BuildConfig.VERSION_NAME

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
