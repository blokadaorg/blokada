package core

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.drawable.Drawable
import android.net.Uri
import com.github.salomonbrys.kodein.*
import filter.DefaultHostlineProcessor
import filter.IHostlineProcessor
import gs.environment.Environment
import gs.environment.Journal
import gs.environment.Worker
import gs.environment.inject
import gs.property.IProperty
import gs.property.newProperty
import nl.komponents.kovenant.task
import org.blokada.R
import tunnel.FilterSourceDescriptor

abstract class Filters {
    abstract val changed: IProperty<Boolean>
    abstract val apps: IProperty<List<App>>
}

class FiltersImpl(
        private val kctx: Worker,
        private val xx: Environment,
        private val ctx: Context = xx().instance()
) : Filters() {

    override val changed = newProperty(kctx, { false })

    private val appsRefresh = {
        val ktx = "filters:apps:refresh".ktx()
        ktx.v("apps refresh start")

        val installed = ctx.packageManager.getInstalledApplications(PackageManager.GET_META_DATA)
                .filter { it.packageName != ctx.packageName }
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
        bind<AppInstallReceiver>() with singleton { AppInstallReceiver() }
        onReady {
            val s: Filters = instance()
            val t: Tunnel = instance()
            val j: Journal = instance()

            // Compile filters every time they change
            s.changed.doWhenChanged(withInit = true).then {
                if (s.changed()) {
                    entrypoint.onFiltersChanged()
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

internal fun id(name: String, whitelist: Boolean): String {
    return if (whitelist) "${name}_wl" else name
}

internal fun sourceToName(ctx: android.content.Context, source: FilterSourceDescriptor): String {
    val name = when (source.id) {
        "link" -> {
            ctx.getString(R.string.filter_name_link, source.source)
        }
        "file" -> {
            val source = try {
                Uri.parse(source.source)
            } catch (e: Exception) {
                null
            }
            ctx.getString(R.string.filter_name_file, source?.lastPathSegment
                    ?: ctx.getString(R.string.filter_name_file_unknown))
        }
        "app" -> {
            try {
                ctx.packageManager.getApplicationLabel(
                        ctx.packageManager.getApplicationInfo(source.source, PackageManager.GET_META_DATA)
                ).toString()
            } catch (e: Exception) {
                source.source
            }
        }
        else -> null
    }

    return name ?: source.source
}

internal fun sourceToIcon(ctx: android.content.Context, source: String): Drawable? {
    return try {
        ctx.packageManager.getApplicationIcon(
                ctx.packageManager.getApplicationInfo(source, PackageManager.GET_META_DATA)
        )
    } catch (e: Exception) {
        null
    }
}
