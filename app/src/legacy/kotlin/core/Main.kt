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
import gs.environment.inject
import gs.environment.newGscoreModule
import gs.property.Device
import gs.property.IWhen
import gs.property.newDeviceModule
import gs.property.newUserModule
import io.paperdb.Paper
import tunnel.blokadaUserAgent
import tunnel.newRestApiModule


/**
 * Main.kt contains all entry points of the app.
 */

private fun startThroughJobScheduler(
        ctx: Context,
        scheduler: JobScheduler = ctx.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler
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
        import(newBatteryModule(this@MainApplication))
        import(newRestApiModule(this@MainApplication))
        import(newAppModule(this@MainApplication), allowOverride = true)
        import(newFlavorModule(this@MainApplication), allowOverride = true)
        import(newBuildTypeModule(this@MainApplication), allowOverride = true)
    }

    override fun onCreate() {
        super.onCreate()
        Paper.init(this)
        defaultWriter.ctx = this
        val ktx = "boot".ktx()
        repeat(10) { ktx.v("BLOKADA", "*".repeat(it * 2)) }
        ktx.v(blokadaUserAgent(this))
        setRestartAppOnCrash()
    }

    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(base)
        Paper.init(this)
    }

    private fun setRestartAppOnCrash() {
        Thread.setDefaultUncaughtExceptionHandler { _, ex ->
            try {
                "fatal".ktx().e(ex)
            } catch (e: Exception) {}
            startThroughJobScheduler(this)
            System.exit(2)
        }
    }
}

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent?) {
        "boot".ktx().v("received boot event")
        startThroughJobScheduler(ctx)
    }
}

class BootJobService : JobService() {

    private val d by lazy { inject().instance<Device>() }
    private val t by lazy { inject().instance<Tunnel>() }
    private val ktx by lazy { "boot:service".ktx() }

    override fun onStartJob(params: JobParameters?): Boolean {
        ktx.v("boot job start")
        d.connected.refresh()
        d.onWifi.refresh()
        return scheduleJobFinish(params)
    }

    private fun scheduleJobFinish(params: JobParameters?): Boolean {
        return try {
            when {
                t.active() -> {
                    ktx.v("boot job finnish immediately, already active")
                    false
                }
                !t.enabled() -> {
                    ktx.v("boot job finnish immediately, not enabled")
                    false
                }
                listener != null -> {
                    ktx.v("boot job finnish immediately, service waiting")
                    false
                }
                else -> {
                    ktx.v("boot job scheduling to stop when tunnel active")
                    listener = t.active.doOnUiWhenChanged().then {
                        t.active.cancel(listener)
                        listener = null
                        jobFinished(params, false)
                    }
                    true
                }
            }
        } catch (e: Exception) {
            ktx.e("boot job fail", e)
            false
        }
    }

    private var listener: IWhen? = null

    override fun onStopJob(params: JobParameters?): Boolean {
        return true
    }

}

