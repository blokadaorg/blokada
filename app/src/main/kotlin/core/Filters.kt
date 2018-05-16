package core

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import com.github.salomonbrys.kodein.*
import filter.AFilterAddDialog
import filter.AFilterGenerateDialog
import filter.DefaultHostlineProcessor
import filter.IHostlineProcessor
import gs.environment.Environment
import gs.environment.Journal
import gs.environment.Worker
import gs.property.IProperty
import gs.property.newProperty
import kotlinx.coroutines.experimental.channels.consumeEach
import kotlinx.coroutines.experimental.launch
import kotlinx.coroutines.experimental.runBlocking

abstract class Filters {
    abstract val changed: IProperty<Boolean>
    abstract val apps: IProperty<List<App>>
}

class FiltersImpl(
        private val kctx: Worker,
        private val xx: Environment,
        private val ctx: Context = xx().instance(),
        private val j: Journal = xx().instance()
) : Filters() {

    override val changed = newProperty(kctx, { false })

    private val appsRefresh = {
        j.log("filters: apps: start")
        val installed = ctx.packageManager.getInstalledApplications(PackageManager.GET_META_DATA)
        val a = installed.map {
            App(
                    appId = it.packageName,
                    label = ctx.packageManager.getApplicationLabel(it).toString(),
                    system = (it.flags and ApplicationInfo.FLAG_SYSTEM) != 0
            )
        }.sortedBy { it.label }
        j.log("filters: apps: found ${a.size} apps")
        a
    }

    override val apps = newProperty(kctx, zeroValue = { emptyList<App>() }, refresh = { appsRefresh() },
            shouldRefresh = { it.isEmpty() })

}

fun newFiltersModule(ctx: Context): Kodein.Module {
    return Kodein.Module {
        bind<Filters>() with singleton { FiltersImpl(kctx = with("gscore").instance(10), xx = lazy,
                ctx = ctx) }
        bind<IHostlineProcessor>() with singleton { DefaultHostlineProcessor() }
        bind<AFilterAddDialog>() with provider {
            AFilterAddDialog(ctx, sourceProvider = instance())
        }
        bind<AFilterGenerateDialog>(true) with provider {
            AFilterGenerateDialog(ctx,
                    s = instance(),
                    sourceProvider = instance(),
                    whitelist = true,
                    cmd = instance()
            )
        }
        bind<AFilterGenerateDialog>(false) with provider {
            AFilterGenerateDialog(ctx,
                    s = instance(),
                    sourceProvider = instance(),
                    whitelist = false,
                    cmd = instance()
            )
        }
        onReady {
            val s: Filters = instance()
            val t: Tunnel = instance()
            val j: Journal = instance()
            val cmd: Commands = instance()

            // Reload engine in case whitelisted apps selection changes
            launch {
                var currentApps = listOf<Filter>()
                cmd.channel(MonitorFilters()).consumeEach { filters ->
                    val newApps = filters.filter { it.whitelist && it.active && it.source.id == "app" }
                    if (newApps != currentApps) {
                        currentApps = newApps

                        if (!t.enabled()) {
                        } else if (t.active()) {
                            t.restart %= true
                            t.active %= false
                        } else {
                            t.retries.refresh()
                            t.restart %= false
                            t.active %= true
                        }
                    }
                }
            }

            // Compile filters every time they change
            s.changed.doWhenChanged(withInit = true).then {
                if (s.changed()) {
                    j.log("filters: compiled: refresh ping")
                    runBlocking {
                        cmd.send(SyncHostsCache())
                        cmd.send(SaveFilters())
                    }
                    s.changed %= false
                }
            }

            // Refresh filters list whenever system apps switch is changed
            val ui: UiState = instance()
            ui.showSystemApps.doWhenChanged().then {
//                s.filters %= s.filters()
            }
        }
    }
}

data class DownloadedFilter(
        val id: String,
        val source: IFilterSource,
        val credit: String? = null,
        var active: Boolean = false,
        var whitelist: Boolean = false,
        var hosts: List<String> = emptyList(),
        var hidden: Boolean = false
) {

    override fun hashCode(): Int {
        return source.hashCode()
    }

    override fun equals(other: Any?): Boolean {
        if (other !is DownloadedFilter) return false
        return source.equals(other.source)
    }
}

data class App(
        val appId: String,
        val label: String,
        val system: Boolean
)

interface IFilterSource {
    fun fetch(): List<String>
    fun fromUserInput(vararg string: String): Boolean
    fun toUserInput(): String
    fun serialize(): String
    fun deserialize(string: String, version: Int): IFilterSource
    fun id(): String
}

