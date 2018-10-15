package core

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
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
import gs.environment.inject
import gs.property.IProperty
import gs.property.newProperty
import nl.komponents.kovenant.task

abstract class Filters {
    abstract val changed: IProperty<Boolean>
    abstract val apps: IProperty<List<App>>
}

class FiltersImpl(
        kctx: Worker,
        private val xx: Environment,
        private val ctx: Context = xx().instance()
) : Filters() {

    override val changed = newProperty(kctx, { false })

    private val appsRefresh = {
        val ktx = "filters:apps:refresh".ktx()
        ktx.v("apps refresh start")

        val installed = ctx.packageManager.getInstalledApplications(PackageManager.GET_META_DATA)
        val a = installed.map {
            App(
                    appId = it.packageName,
                    label = ctx.packageManager.getApplicationLabel(it).toString(),
                    system = (it.flags and ApplicationInfo.FLAG_SYSTEM) != 0
            )
        }.sortedBy { it.label }
        ktx.v("found ${a.size} apps")
        a
    }

    override val apps = newProperty(kctx, zeroValue = { emptyList<App>() }, refresh = { appsRefresh() },
            shouldRefresh = { it.isEmpty() })

}

fun newFiltersModule(ctx: Context): Kodein.Module {
    return Kodein.Module {
        bind<Filters>() with singleton {
            FiltersImpl(kctx = with("gscore").instance(10), xx = lazy,
                    ctx = ctx)
        }
        bind<IHostlineProcessor>() with singleton { DefaultHostlineProcessor() }
        bind<AFilterAddDialog>() with provider {
            AFilterAddDialog(ctx, sourceProvider = instance())
        }
        bind<AFilterGenerateDialog>(true) with provider {
            AFilterGenerateDialog(lazy,
                    whitelist = true
            )
        }
        bind<AFilterGenerateDialog>(false) with provider {
            AFilterGenerateDialog(lazy,
                    whitelist = false
            )
        }
        bind<AppInstallReceiver>() with singleton { AppInstallReceiver() }
        onReady {
            val s: Filters = instance()
            val t: Tunnel = instance()
            val j: Journal = instance()
            val m: tunnel.Main = instance()

            // Compile filters every time they change
            s.changed.doWhenChanged(withInit = true).then {
                if (s.changed()) {
                    m.sync(ctx.ktx("filters:sync:after:change"))
                    s.changed %= false
                }
            }

            task {
                // In a task because we are in DI and using DI can lead to stack overflow
                AppInstallReceiver.register(ctx)
            }
        }
    }
}

data class App(
        val appId: String,
        val label: String,
        val system: Boolean
)

class AppInstallReceiver : BroadcastReceiver() {

    override fun onReceive(ctx: Context, intent: Intent?) {
        task(ctx.inject().with("AppInstallReceiver").instance()) {
            "filters:app".ktx().v("app install receiver ping")
            val f: Filters = ctx.inject().instance()
            f.apps.refresh(force = true)
        }
    }

    companion object {
        fun register(ctx: Context) {
            val filter = IntentFilter()
            filter.addAction(Intent.ACTION_PACKAGE_ADDED)
            filter.addAction(Intent.ACTION_PACKAGE_FULLY_REMOVED)
            filter.addDataScheme("package")
            ctx.registerReceiver(ctx.inject().instance<AppInstallReceiver>(), filter)
        }
    }
}
