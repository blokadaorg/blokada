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
import gs.environment.ComponentProvider
import gs.environment.Journal
import gs.environment.inject
import gs.environment.newGscoreModule
import gs.property.Device
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

    override fun onStartJob(params: JobParameters?): Boolean {
        val s: Device = inject().instance()
        val j: Journal = inject().instance()
        j.log("BootJobService: onStartJob")
        s.connected.refresh()
        this.params = params
        return scheduleJobFinish()
    }

    private fun scheduleJobFinish(): Boolean {
        val p: ComponentProvider<BootJobService> = inject().instance()
        // If existing job is still to be finished, just quit
        if (p.get() != null) return false
        p.set(this)
        return true
    }

    private var params: JobParameters? = null

    fun finishJob() {
        try { jobFinished(params, false) } catch (e: Exception) {}
        val p: ComponentProvider<BootJobService> = inject().instance()
        p.unset()
    }

    override fun onStopJob(params: JobParameters?): Boolean {
        return true
    }

}

