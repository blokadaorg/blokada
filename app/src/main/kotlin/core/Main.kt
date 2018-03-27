package core

import android.app.Application
import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import buildtype.newBuildTypeModule
import com.github.salomonbrys.kodein.Kodein
import com.github.salomonbrys.kodein.KodeinAware
import com.github.salomonbrys.kodein.instance
import com.github.salomonbrys.kodein.lazy
import flavor.newFlavorModule
import gs.environment.Journal
import gs.environment.inject
import gs.environment.newGscoreModule
import gs.property.Device
import gs.property.IWhen
import gs.property.newDeviceModule
import gs.property.newUserModule

/**
 * Main.kt contains all entry points of the app.
 */

private fun startThroughJobScheduler(
        ctx: Context,
        scheduler: JobScheduler = ctx.inject().instance()
) {
    val serviceComponent = ComponentName(ctx, BootJobService::class.java)
    val builder = JobInfo.Builder(0, serviceComponent)
    builder.setOverrideDeadline(3 * 1000L)
    scheduler.schedule(builder.build())
}

class MainApplication: Application(), KodeinAware {

    override val kodein by Kodein.lazy {
        import(newGscoreModule(this@MainApplication))
        import(newDeviceModule(this@MainApplication))
        import(newUserModule(this@MainApplication))
        import(newTunnelModule(this@MainApplication))
        import(newFiltersModule(this@MainApplication))
        import(newDnsModule(this@MainApplication))
        import(newWelcomeModule(this@MainApplication))
        import(newPagesModule(this@MainApplication))
        import(newUpdateModule(this@MainApplication))
        import(newKeepAliveModule(this@MainApplication))
        import(newAppModule(this@MainApplication), allowOverride = true)
        import(newFlavorModule(this@MainApplication), allowOverride = true)
        import(newBuildTypeModule(this@MainApplication), allowOverride = true)
    }

    override fun onCreate() {
        super.onCreate()
        setRestartAppOnCrash()
    }

    private fun setRestartAppOnCrash() {
        Thread.setDefaultUncaughtExceptionHandler { _, ex ->
            try {
                val j: Journal = inject().instance()
                j.log("fatal", ex)
            } catch (e: Exception) {}
            startThroughJobScheduler(this)
            System.exit(2)
        }
    }
}

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent?) {
        startThroughJobScheduler(ctx)
    }
}

class BootJobService : JobService() {

    private val j by lazy { inject().instance<Journal>() }
    private val d by lazy { inject().instance<Device>() }
    private val t by lazy { inject().instance<Tunnel>() }

    override fun onStartJob(params: JobParameters?): Boolean {
        j.log("BootJobService: onStartJob")
        d.connected.refresh()
        return scheduleJobFinish(params)
    }

    private fun scheduleJobFinish(params: JobParameters?): Boolean {
        return try {
            when {
                t.active() -> {
                    j.log("BootJobService: finnish immediately, already active")
                    false
                }
                !t.enabled() -> {
                    j.log("BootJobService: finnish immediately, not enabled")
                    false
                }
                listener != null -> {
                    j.log("BootJobService: finnish immediately, service waiting")
                    false
                }
                else -> {
                    j.log("BootJobService: scheduling to stop when tunnel active")
                    listener = t.active.doOnUiWhenChanged().then {
                        t.active.cancel(listener)
                        listener = null
                        jobFinished(params, false)
                    }
                    true
                }
            }
        } catch (e: Exception) {
            j.log("BootJobService: finish immediately, error", e)
            false
        }
    }

    private var listener: IWhen? = null

    override fun onStopJob(params: JobParameters?): Boolean {
        return true
    }

}

